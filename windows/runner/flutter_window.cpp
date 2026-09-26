#include "flutter_window.h"

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {

bool ReadDoubleArgument(const flutter::EncodableMap& arguments,
                        const char* name,
                        double* value) {
  const auto entry = arguments.find(flutter::EncodableValue(name));
  if (entry == arguments.end()) {
    return false;
  }

  const auto* number = std::get_if<double>(&entry->second);
  if (number == nullptr) {
    return false;
  }

  *value = *number;
  return true;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }

  window_channel_ = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "relgeo/window",
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() != "configure") {
          result->NotImplemented();
          return;
        }

        const auto* arguments = std::get_if<flutter::EncodableMap>(
            &call.arguments());
        double default_width = 0;
        double default_height = 0;
        double minimum_width = 0;
        double minimum_height = 0;
        if (arguments == nullptr ||
            !ReadDoubleArgument(*arguments, "defaultWidth", &default_width) ||
            !ReadDoubleArgument(
                *arguments, "defaultHeight", &default_height) ||
            !ReadDoubleArgument(
                *arguments, "minimumWidth", &minimum_width) ||
            !ReadDoubleArgument(
                *arguments, "minimumHeight", &minimum_height) ||
            default_width <= 0 || default_height <= 0 || minimum_width <= 0 ||
            minimum_height <= 0) {
          result->Error("invalid_arguments", "Invalid window dimensions.");
          return;
        }

        const UINT dpi = GetDpiForWindow(GetHandle());
        const double scale_factor = dpi == 0 ? 1.0 : dpi / 96.0;
        const int width = static_cast<int>(default_width * scale_factor);
        const int height = static_cast<int>(default_height * scale_factor);
        RECT current_rect;
        GetWindowRect(GetHandle(), &current_rect);
        SetWindowPos(GetHandle(), nullptr, current_rect.left, current_rect.top,
                     width, height, SWP_NOZORDER | SWP_NOACTIVATE);
        result->Success(flutter::EncodableValue());
      });

  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
