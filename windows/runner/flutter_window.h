#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"
#include <commctrl.h>

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void RegisterAppBar();
  void UnregisterAppBar();
  void RepositionAppBar();
  void SetWindowEffect(const flutter::EncodableMap& arguments);
  void ShowNativeTooltip(const flutter::EncodableMap& arguments);
  void HideNativeTooltip();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;
  bool appbar_registered_ = false;
  UINT appbar_callback_message_ = WM_APP + 37;
  HWND tooltip_window_ = nullptr;
  TOOLINFOW tooltip_info_{};
  std::wstring tooltip_text_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
