#include "flutter_window.h"

#include <commctrl.h>
#include <dwmapi.h>
#include <shellapi.h>
#include <windowsx.h>

#include <algorithm>
#include <optional>

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
