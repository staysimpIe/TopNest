import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:topnest/controllers/widget_layout_controller.dart';
import 'package:topnest/models/desktop_widget_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('默认三个组件顺序正确', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = WidgetLayoutController(preferences)..load();
    expect(controller.slots, WidgetLayoutController.defaultSlots);
  });

  test('移除保留空槽、添加进入首个空槽并可交换', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = WidgetLayoutController(preferences)..load();
    expect(controller.remove(DesktopWidgetType.gemini), isTrue);
    expect(controller.slots[1], isNull);
    expect(controller.add(DesktopWidgetType.gemini), isTrue);
    expect(controller.add(DesktopWidgetType.gemini), isFalse);
    controller.move(0, 2);
    expect(controller.slots.first, DesktopWidgetType.claudeAndGpt);
    expect(controller.slots.last, DesktopWidgetType.codex);
  });

  test('持久化时安全清理未知项和重复项', () async {
    SharedPreferences.setMockInitialValues({
      'widgetSlots': ['codex', 'unknown', 'codex'],
    });
    final preferences = await SharedPreferences.getInstance();
    final controller = WidgetLayoutController(preferences)..load();
    expect(controller.slots, [DesktopWidgetType.codex, null, null]);
    controller.replace([
      DesktopWidgetType.gemini,
      null,
      DesktopWidgetType.claudeAndGpt,
    ]);
    await controller.save();
    final restored = WidgetLayoutController(preferences)..load();
    expect(restored.slots, controller.slots);
  });

  test('主窗口可直接应用设置窗口传入的槽位', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = WidgetLayoutController(preferences)..load();

    controller.replaceByNames(['claudeAndGpt', '', 'codex']);

    expect(controller.slots, [
      DesktopWidgetType.claudeAndGpt,
      null,
      DesktopWidgetType.codex,
    ]);
  });
}
