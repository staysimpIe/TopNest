#include "flutter_window.h"

#include <audiopolicy.h>
#include <commctrl.h>
#include <dwmapi.h>
#include <endpointvolume.h>
#include <mmdeviceapi.h>
#include <shellapi.h>
#include <tlhelp32.h>
#include <windowsx.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Media.Control.h>
#include <winrt/Windows.Storage.Streams.h>

#include <wrl/client.h>

#include <algorithm>
#include <cctype>
#include <chrono>
#include <functional>
#include <optional>
#include <thread>
#include <vector>

#include <flutter/standard_method_codec.h>

#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include "flutter/generated_plugin_registrant.h"

namespace {
constexpr int kLogicalBarHeight = 36;
constexpr DWORD kDwmaSystemBackdropType = 38;
constexpr DWORD kDwmaBorderColor = 34;
constexpr COLORREF kDwmColorNone = 0xFFFFFFFE;
constexpr int kDwmBackdropNone = 1;
constexpr int kDwmBackdropTransientWindow = 3;
constexpr UINT kMediaResultMessage = WM_APP + 38;

struct MediaMethodResponse {
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
  flutter::EncodableValue value;
  std::string error;
};

enum WindowCompositionAttribute { kWindowCompositionAttributeAccentPolicy = 19 };
enum AccentState {
  kAccentDisabled = 0,
  kAccentTransparentGradient = 2,
  kAccentAcrylicBlurBehind = 4,
};
struct AccentPolicy {
  int accent_state;
  int accent_flags;
  DWORD gradient_color;
  int animation_id;
};
struct WindowCompositionAttributeData {
  WindowCompositionAttribute attribute;
  PVOID data;
  SIZE_T size_of_data;
};
using SetWindowCompositionAttributeFn = BOOL(WINAPI*)(
    HWND, WindowCompositionAttributeData*);

const flutter::EncodableValue* FindValue(const flutter::EncodableMap& map,
                                         const char* key) {
  auto iterator = map.find(flutter::EncodableValue(key));
  return iterator == map.end() ? nullptr : &iterator->second;
}

double NumberValue(const flutter::EncodableMap& map, const char* key,
                   double fallback) {
  const auto* value = FindValue(map, key);
  if (value == nullptr) return fallback;
  if (const auto* number = std::get_if<double>(value)) return *number;
  if (const auto* number = std::get_if<int32_t>(value)) {
    return static_cast<double>(*number);
  }
  if (const auto* number = std::get_if<int64_t>(value)) {
    return static_cast<double>(*number);
  }
  return fallback;
}

bool BoolValue(const flutter::EncodableMap& map, const char* key,
               bool fallback) {
  const auto* value = FindValue(map, key);
  const auto* result = value == nullptr ? nullptr : std::get_if<bool>(value);
  return result == nullptr ? fallback : *result;
}

std::string StringValue(const flutter::EncodableMap& map, const char* key) {
  const auto* value = FindValue(map, key);
  const auto* result = value == nullptr ? nullptr : std::get_if<std::string>(value);
  return result == nullptr ? std::string() : *result;
}

std::wstring Utf8ToWide(const std::string& text) {
  if (text.empty()) return std::wstring();
  const int length = MultiByteToWideChar(CP_UTF8, 0, text.data(),
                                         static_cast<int>(text.size()), nullptr, 0);
  std::wstring result(length, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
                      result.data(), length);
  return result;
}

std::string WideToUtf8(const std::wstring& text) {
  if (text.empty()) return std::string();
  const int length = WideCharToMultiByte(
      CP_UTF8, 0, text.data(), static_cast<int>(text.size()), nullptr, 0,
      nullptr, nullptr);
  std::string result(length, '\0');
  WideCharToMultiByte(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
                      result.data(), length, nullptr, nullptr);
  return result;
}

using MediaSession = winrt::Windows::Media::Control::
    GlobalSystemMediaTransportControlsSession;
using MediaSessionManager = winrt::Windows::Media::Control::
    GlobalSystemMediaTransportControlsSessionManager;

bool IsNeteaseSource(const winrt::hstring& source_id) {
  std::wstring source = source_id.c_str();
  std::transform(source.begin(), source.end(), source.begin(), towlower);
  return source.find(L"cloudmusic") != std::wstring::npos ||
         source.find(L"netease") != std::wstring::npos ||
         source.find(L"music.163") != std::wstring::npos ||
         source.find(L"122165ae053f") != std::wstring::npos;
}

MediaSession FindMediaSession() {
  const auto manager = MediaSessionManager::RequestAsync().get();
  const auto current_session = manager.GetCurrentSession();
  if (current_session != nullptr) return current_session;

  // 旧版网易云有时不会成为 Windows 当前媒体会话，保留匹配作为兼容回退。
  for (const auto& session : manager.GetSessions()) {
    if (IsNeteaseSource(session.SourceAppUserModelId())) return session;
  }
  return nullptr;
}

bool IsNeteaseRunning() {
  const HANDLE snapshot =
      CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) return false;
  PROCESSENTRY32W process{sizeof(PROCESSENTRY32W)};
  bool running = false;
  if (Process32FirstW(snapshot, &process)) {
    do {
      if (_wcsicmp(process.szExeFile, L"cloudmusic.exe") == 0) {
        running = true;
        break;
      }
    } while (Process32NextW(snapshot, &process));
  }
  CloseHandle(snapshot);
  return running;
}

bool IsNeteaseProcess(DWORD process_id) {
  const HANDLE process =
      OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
  if (process == nullptr) return false;
  wchar_t path[MAX_PATH]{};
  DWORD path_length = MAX_PATH;
  const bool path_found =
      QueryFullProcessImageNameW(process, 0, path, &path_length) != FALSE;
  const wchar_t* file_name = wcsrchr(path, L'\\');
  if (file_name == nullptr) file_name = path;
  else ++file_name;
  const bool matched =
      path_found && _wcsicmp(file_name, L"cloudmusic.exe") == 0;
  CloseHandle(process);
  return matched;
}

std::string GetNeteaseWindowTitle() {
  struct SearchData {
    std::wstring title;
  } data;
  EnumWindows(
      [](HWND window, LPARAM parameter) -> BOOL {
        if (!IsWindowVisible(window)) return TRUE;
        DWORD process_id = 0;
        GetWindowThreadProcessId(window, &process_id);
        if (!IsNeteaseProcess(process_id)) return TRUE;
        const int length = GetWindowTextLengthW(window);
        if (length <= 0) return TRUE;
        std::wstring title(static_cast<size_t>(length) + 1, L'\0');
        GetWindowTextW(window, title.data(), length + 1);
        title.resize(static_cast<size_t>(length));
        static_cast<SearchData*>(reinterpret_cast<void*>(parameter))->title =
            std::move(title);
        return FALSE;
      },
      reinterpret_cast<LPARAM>(&data));
  return WideToUtf8(data.title);
}

bool IsNeteaseAudioPlaying() {
  using Microsoft::WRL::ComPtr;
  ComPtr<IMMDeviceEnumerator> device_enumerator;
  if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                              CLSCTX_ALL, IID_PPV_ARGS(&device_enumerator)))) {
    return false;
  }
  ComPtr<IMMDevice> device;
  if (FAILED(device_enumerator->GetDefaultAudioEndpoint(
          eRender, eMultimedia, &device))) {
    return false;
  }
  ComPtr<IAudioSessionManager2> manager;
  if (FAILED(device->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL,
                              nullptr, &manager))) {
    return false;
  }
  ComPtr<IAudioSessionEnumerator> sessions;
  if (FAILED(manager->GetSessionEnumerator(&sessions))) return false;
  int count = 0;
  if (FAILED(sessions->GetCount(&count))) return false;
  for (int index = 0; index < count; ++index) {
    ComPtr<IAudioSessionControl> control;
    if (FAILED(sessions->GetSession(index, &control))) continue;
    ComPtr<IAudioSessionControl2> control2;
    if (FAILED(control.As(&control2))) continue;
    DWORD process_id = 0;
    if (FAILED(control2->GetProcessId(&process_id)) ||
        !IsNeteaseProcess(process_id)) {
      continue;
    }
    ComPtr<IAudioMeterInformation> meter;
    if (SUCCEEDED(control.As(&meter))) {
      // 会话在播放器暂停后仍可能保持 Active，采样峰值才能判断是否
      // 仍有音频数据输出。短时间多次采样可避开单个设备周期的零值。
      for (int sample = 0; sample < 6; ++sample) {
        float peak = 0.0f;
        if (SUCCEEDED(meter->GetPeakValue(&peak)) && peak > 0.000001f) {
          return true;
        }
        Sleep(35);
      }
    }
  }
  return false;
}

void SendMediaKey(WORD key) {
  INPUT inputs[2]{};
  inputs[0].type = INPUT_KEYBOARD;
  inputs[0].ki.wVk = key;
  inputs[1] = inputs[0];
  inputs[1].ki.dwFlags = KEYEVENTF_KEYUP;
  SendInput(2, inputs, sizeof(INPUT));
}

flutter::EncodableMap ReadMediaState() {
  flutter::EncodableMap state;
  const auto session = FindMediaSession();
  state[flutter::EncodableValue("available")] =
      flutter::EncodableValue(session != nullptr);
  if (session == nullptr) {
    const bool netease_audio_active = IsNeteaseAudioPlaying();
    state[flutter::EncodableValue("neteaseRunning")] =
        flutter::EncodableValue(IsNeteaseRunning());
    state[flutter::EncodableValue("windowTitle")] =
        flutter::EncodableValue(GetNeteaseWindowTitle());
    state[flutter::EncodableValue("playing")] =
        flutter::EncodableValue(netease_audio_active);
    state[flutter::EncodableValue("audioActive")] =
        flutter::EncodableValue(netease_audio_active);
    state[flutter::EncodableValue("error")] =
        flutter::EncodableValue("请打开支持系统媒体会话的音乐播放器并播放歌曲");
    return state;
  }

  const bool netease_session = IsNeteaseSource(session.SourceAppUserModelId());
  state[flutter::EncodableValue("neteaseSession")] =
      flutter::EncodableValue(netease_session);
  if (netease_session) {
    state[flutter::EncodableValue("windowTitle")] =
        flutter::EncodableValue(GetNeteaseWindowTitle());
  }
  const auto properties = session.TryGetMediaPropertiesAsync().get();
  const auto playback = session.GetPlaybackInfo();
  const auto controls = playback.Controls();
  const auto timeline = session.GetTimelineProperties();
  const bool playing =
      playback.PlaybackStatus() == winrt::Windows::Media::Control::
                                       GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing;
  const auto raw_position = timeline.Position();
  auto position = raw_position;
  if (playing) {
    const auto elapsed = winrt::clock::now() - timeline.LastUpdatedTime();
    if (elapsed > decltype(elapsed)::zero() &&
        elapsed < std::chrono::hours(24)) {
      position += std::chrono::duration_cast<decltype(position)>(elapsed);
      position = std::min(position, timeline.EndTime());
    }
  }
  state[flutter::EncodableValue("title")] =
      flutter::EncodableValue(WideToUtf8(properties.Title().c_str()));
  state[flutter::EncodableValue("artist")] =
      flutter::EncodableValue(WideToUtf8(properties.Artist().c_str()));
  state[flutter::EncodableValue("album")] =
      flutter::EncodableValue(WideToUtf8(properties.AlbumTitle().c_str()));
  state[flutter::EncodableValue("playing")] = flutter::EncodableValue(playing);
  state[flutter::EncodableValue("canPrevious")] =
      flutter::EncodableValue(controls.IsPreviousEnabled());
  state[flutter::EncodableValue("canNext")] =
      flutter::EncodableValue(controls.IsNextEnabled());
  state[flutter::EncodableValue("canPlayPause")] =
      flutter::EncodableValue(controls.IsPlayPauseToggleEnabled());
  state[flutter::EncodableValue("positionMs")] = flutter::EncodableValue(
      static_cast<int64_t>(position.count() / 10000));
  state[flutter::EncodableValue("rawPositionMs")] = flutter::EncodableValue(
      static_cast<int64_t>(raw_position.count() / 10000));
  if (netease_session) {
    state[flutter::EncodableValue("audioActive")] =
        flutter::EncodableValue(IsNeteaseAudioPlaying());
  }
  state[flutter::EncodableValue("durationMs")] = flutter::EncodableValue(
      static_cast<int64_t>(timeline.EndTime().count() / 10000));
  const auto thumbnail = properties.Thumbnail();
  if (thumbnail != nullptr) {
    const auto stream = thumbnail.OpenReadAsync().get();
    const uint64_t size = std::min<uint64_t>(stream.Size(), 5 * 1024 * 1024);
    if (size > 0) {
      winrt::Windows::Storage::Streams::DataReader reader(stream);
      reader.LoadAsync(static_cast<uint32_t>(size)).get();
      std::vector<uint8_t> bytes(static_cast<size_t>(size));
      reader.ReadBytes(bytes);
      state[flutter::EncodableValue("cover")] =
          flutter::EncodableValue(bytes);
    }
  }
  return state;
}

void ControlMedia(const flutter::EncodableMap& arguments) {
  const auto session = FindMediaSession();
  const std::string action = StringValue(arguments, "action");
  if (session == nullptr) {
    if (action == "previous") {
      SendMediaKey(VK_MEDIA_PREV_TRACK);
    } else if (action == "next") {
      SendMediaKey(VK_MEDIA_NEXT_TRACK);
    } else if (action == "playPause") {
      SendMediaKey(VK_MEDIA_PLAY_PAUSE);
    }
    return;
  }
  if (action == "previous") {
    session.TrySkipPreviousAsync().get();
  } else if (action == "next") {
    session.TrySkipNextAsync().get();
  } else if (action == "playPause") {
    session.TryTogglePlayPauseAsync().get();
  }
}

void RunMediaTask(
    HWND window,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
    std::function<flutter::EncodableValue()> task) {
  std::thread([window, result = std::move(result), task = std::move(task)]()
                  mutable {
    MediaMethodResponse response{std::move(result), flutter::EncodableValue(),
                                 std::string()};
    bool apartment_initialized = false;
    try {
      // WinRT 的异步媒体接口不能在 Flutter 的 STA 主线程上同步等待。
      winrt::init_apartment(winrt::apartment_type::multi_threaded);
      apartment_initialized = true;
      response.value = task();
    } catch (const winrt::hresult_error& error) {
      response.error = WideToUtf8(error.message().c_str());
    }
    if (apartment_initialized) winrt::uninit_apartment();
    if (IsWindow(window)) {
      SendMessage(window, kMediaResultMessage, 0,
                  reinterpret_cast<LPARAM>(&response));
    }
  }).detach();
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) return false;

  RECT frame = GetClientArea();
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) return false;
  RegisterPlugins(flutter_controller_->engine());
  // 每个设置子窗口都有独立 Flutter Engine，必须重新注册全部插件。
  DesktopMultiWindowSetWindowCreatedCallback([](void* controller) {
    auto* flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController*>(controller);
    RegisterPlugins(flutter_view_controller->engine());
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  method_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "topnest/appbar",
          &flutter::StandardMethodCodec::GetInstance());
  method_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
        if (call.method_name() == "register") {
          RegisterAppBar();
        } else if (call.method_name() == "unregister") {
          UnregisterAppBar();
        } else if (call.method_name() == "reposition") {
          RepositionAppBar();
        } else if (call.method_name() == "setEffect" && arguments != nullptr) {
          SetWindowEffect(*arguments);
        } else if (call.method_name() == "showTooltip" && arguments != nullptr) {
          ShowNativeTooltip(*arguments);
        } else if (call.method_name() == "hideTooltip") {
          HideNativeTooltip();
        } else if (call.method_name() == "getMediaState") {
          RunMediaTask(GetHandle(), std::move(result), []() {
            return flutter::EncodableValue(ReadMediaState());
          });
          return;
        } else if (call.method_name() == "mediaControl" && arguments != nullptr) {
          const auto media_arguments = *arguments;
          RunMediaTask(
              GetHandle(), std::move(result), [media_arguments]() {
                ControlMedia(media_arguments);
                return flutter::EncodableValue();
              });
          return;
        } else {
          result->NotImplemented();
          return;
        }
        result->Success();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() { this->Show(); });
  flutter_controller_->ForceRedraw();
  return true;
}

void FlutterWindow::OnDestroy() {
  HideNativeTooltip();
  if (tooltip_window_ != nullptr) {
    DestroyWindow(tooltip_window_);
    tooltip_window_ = nullptr;
  }
  UnregisterAppBar();
  method_channel_.reset();
  flutter_controller_.reset();
  Win32Window::OnDestroy();
}

void FlutterWindow::RegisterAppBar() {
  if (appbar_registered_) return;
  APPBARDATA data{sizeof(APPBARDATA)};
  data.hWnd = GetHandle();
  data.uCallbackMessage = appbar_callback_message_;
  appbar_registered_ = SHAppBarMessage(ABM_NEW, &data) != 0;
  LONG_PTR style = GetWindowLongPtr(GetHandle(), GWL_STYLE);
  style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MAXIMIZEBOX | WS_MINIMIZEBOX);
  SetWindowLongPtr(GetHandle(), GWL_STYLE, style);
  LONG_PTR extended = GetWindowLongPtr(GetHandle(), GWL_EXSTYLE);
  extended |= WS_EX_TOOLWINDOW;
  extended &= ~WS_EX_APPWINDOW;
  SetWindowLongPtr(GetHandle(), GWL_EXSTYLE, extended);
  // Windows 11 会为无边框窗口保留一圈 DWM 描边，显式关闭它。
  DwmSetWindowAttribute(GetHandle(), kDwmaBorderColor, &kDwmColorNone,
                        sizeof(kDwmColorNone));
  RepositionAppBar();
}

void FlutterWindow::UnregisterAppBar() {
  if (!appbar_registered_) return;
  APPBARDATA data{sizeof(APPBARDATA)};
  data.hWnd = GetHandle();
  SHAppBarMessage(ABM_REMOVE, &data);
  appbar_registered_ = false;
}

void FlutterWindow::RepositionAppBar() {
  if (!appbar_registered_) return;
  POINT origin{0, 0};
  MONITORINFO monitor{sizeof(MONITORINFO)};
  GetMonitorInfo(MonitorFromPoint(origin, MONITOR_DEFAULTTOPRIMARY), &monitor);
  const UINT dpi = GetDpiForWindow(GetHandle());
  const int height = MulDiv(kLogicalBarHeight, dpi == 0 ? 96 : dpi, 96);
  APPBARDATA data{sizeof(APPBARDATA)};
  data.hWnd = GetHandle();
  data.uEdge = ABE_TOP;
  data.rc = monitor.rcMonitor;
  data.rc.bottom = data.rc.top + height;
  SHAppBarMessage(ABM_QUERYPOS, &data);
  data.rc.bottom = data.rc.top + height;
  SHAppBarMessage(ABM_SETPOS, &data);
  SetWindowPos(GetHandle(), HWND_TOPMOST, data.rc.left, data.rc.top,
               data.rc.right - data.rc.left, data.rc.bottom - data.rc.top,
               SWP_NOACTIVATE | SWP_FRAMECHANGED);
}

void FlutterWindow::SetWindowEffect(const flutter::EncodableMap& arguments) {
  const bool acrylic = BoolValue(arguments, "acrylic", true);
  const bool dark = BoolValue(arguments, "dark", false);
  const double alpha = std::clamp(NumberValue(arguments, "alpha", 0.55), 0.0, 1.0);
  const int red = std::clamp(static_cast<int>(NumberValue(arguments, "red", 245)), 0, 255);
  const int green = std::clamp(static_cast<int>(NumberValue(arguments, "green", 245)), 0, 255);
  const int blue = std::clamp(static_cast<int>(NumberValue(arguments, "blue", 245)), 0, 255);

  const int backdrop =
      acrylic && !dark ? kDwmBackdropTransientWindow : kDwmBackdropNone;
  const bool use_system_acrylic =
      acrylic && !dark &&
      SUCCEEDED(DwmSetWindowAttribute(GetHandle(), kDwmaSystemBackdropType,
                                      &backdrop, sizeof(backdrop)));
  if (!use_system_acrylic) {
    const int no_backdrop = kDwmBackdropNone;
    DwmSetWindowAttribute(GetHandle(), kDwmaSystemBackdropType, &no_backdrop,
                          sizeof(no_backdrop));
  }

  auto set_composition = reinterpret_cast<SetWindowCompositionAttributeFn>(
      GetProcAddress(GetModuleHandle(L"user32.dll"),
                     "SetWindowCompositionAttribute"));
  if (set_composition == nullptr) return;
  const DWORD color = (static_cast<DWORD>(alpha * 255) << 24) |
                      (static_cast<DWORD>(blue) << 16) |
                      (static_cast<DWORD>(green) << 8) |
                      static_cast<DWORD>(red);
  // DWM 背景成功时仍需让 Flutter 合成层保持透明，否则毛玻璃会被遮住。
  AccentPolicy policy{
      acrylic && !use_system_acrylic ? kAccentAcrylicBlurBehind
                                     : kAccentTransparentGradient,
      2, color, 0};
  WindowCompositionAttributeData data{
      kWindowCompositionAttributeAccentPolicy, &policy, sizeof(policy)};
  set_composition(GetHandle(), &data);
}

void FlutterWindow::ShowNativeTooltip(const flutter::EncodableMap& arguments) {
  tooltip_text_ = Utf8ToWide(StringValue(arguments, "text"));
  if (tooltip_text_.empty()) return;
  if (tooltip_window_ == nullptr) {
    INITCOMMONCONTROLSEX controls{sizeof(INITCOMMONCONTROLSEX), ICC_WIN95_CLASSES};
    InitCommonControlsEx(&controls);
    tooltip_window_ = CreateWindowEx(
        WS_EX_TOPMOST | WS_EX_NOACTIVATE, TOOLTIPS_CLASS, nullptr,
        WS_POPUP | TTS_NOPREFIX | TTS_ALWAYSTIP, CW_USEDEFAULT, CW_USEDEFAULT,
        CW_USEDEFAULT, CW_USEDEFAULT, GetHandle(), nullptr, GetModuleHandle(nullptr),
        nullptr);
    SetWindowPos(tooltip_window_, HWND_TOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  }
  if (tooltip_window_ == nullptr) return;
  if (tooltip_info_.cbSize == 0) {
    tooltip_info_.cbSize = sizeof(TOOLINFOW);
    tooltip_info_.uFlags = TTF_TRACK | TTF_ABSOLUTE;
    tooltip_info_.hwnd = GetHandle();
    tooltip_info_.uId = 1;
    tooltip_info_.lpszText = tooltip_text_.data();
    SendMessage(tooltip_window_, TTM_ADDTOOLW, 0,
                reinterpret_cast<LPARAM>(&tooltip_info_));
  } else {
    tooltip_info_.lpszText = tooltip_text_.data();
    SendMessage(tooltip_window_, TTM_UPDATETIPTEXTW, 0,
                reinterpret_cast<LPARAM>(&tooltip_info_));
  }
  const UINT dpi = GetDpiForWindow(GetHandle());
  POINT point{
      MulDiv(static_cast<int>(NumberValue(arguments, "x", 0)), dpi, 96),
      MulDiv(static_cast<int>(NumberValue(arguments, "y", 0)), dpi, 96)};
  ClientToScreen(GetHandle(), &point);
  SendMessage(tooltip_window_, TTM_TRACKPOSITION, 0, MAKELPARAM(point.x, point.y));
  SendMessage(tooltip_window_, TTM_TRACKACTIVATE, TRUE,
              reinterpret_cast<LPARAM>(&tooltip_info_));
}

void FlutterWindow::HideNativeTooltip() {
  if (tooltip_window_ != nullptr && tooltip_info_.cbSize != 0) {
    SendMessage(tooltip_window_, TTM_TRACKACTIVATE, FALSE,
                reinterpret_cast<LPARAM>(&tooltip_info_));
  }
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == kMediaResultMessage) {
    auto* response = reinterpret_cast<MediaMethodResponse*>(lparam);
    if (response != nullptr && response->result != nullptr) {
      if (response->error.empty()) {
        response->result->Success(response->value);
      } else {
        response->result->Error("media_error", response->error);
      }
    }
    return 0;
  }
  if (message == appbar_callback_message_ && wparam == ABN_POSCHANGED) {
    RepositionAppBar();
    return 0;
  }
  if (message == WM_DISPLAYCHANGE || message == WM_SETTINGCHANGE) {
    RepositionAppBar();
  }
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
    if (result) return *result;
  }
  if (message == WM_FONTCHANGE && flutter_controller_) {
    flutter_controller_->engine()->ReloadSystemFonts();
  }
  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
