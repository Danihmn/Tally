import 'package:material_ui/material_ui.dart';

/// The most a modal bottom sheet may take of the screen height, drag handle
/// included.
const double appSheetMaxHeightFraction = 0.8;

/// Shows a modal bottom sheet over the tabs, with the app's layout: it never
/// takes more than [appSheetMaxHeightFraction] of the screen. Taller content
/// scrolls inside the sheet (the body of every sheet already scrolls).
///
/// Every modal sheet of the app goes through here, so the layout of the sheets
/// is changed in this one place.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  // Over the tabs, like in the prototype.
  useRootNavigator: true,
  // Lets the sheet grow up to the cap below instead of the Material default
  // of 9/16 of the screen.
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheetContext) => _AppSheetFrame(child: builder(sheetContext)),
);

/// Caps the content so the whole sheet (content plus drag handle) stays within
/// [appSheetMaxHeightFraction] of the screen.
class _AppSheetFrame extends StatelessWidget {
  const _AppSheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxHeight =
        screenHeight * appSheetMaxHeightFraction - kMinInteractiveDimension;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight < 0 ? 0 : maxHeight),
      child: child,
    );
  }
}
