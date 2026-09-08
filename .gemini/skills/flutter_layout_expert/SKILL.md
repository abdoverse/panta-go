---
name: Flutter Layout & Overflow Expert
description: A set of strict rules and patterns for preventing UI rendering issues, RenderFlex overflows, and layout constraints in Flutter.
---

# Flutter Layout & Overflow Expert

This skill equips Antigravity with the knowledge to proactively detect, prevent, and fix common layout and rendering issues in Flutter. Before writing or modifying Flutter UI code, always review these rules to ensure robust, overflow-free layouts across all screen sizes and platforms.

## 1. Material Minimum Tap Targets
**The Issue:** Material components (`ActionChip`, `IconButton`, `TextButton`, `Checkbox`) strictly enforce a minimum tap-target area of 48x48 pixels by default. 
**The Prevention:** 
- **NEVER** place a Material widget inside a `Container` or `SizedBox` with a height or width less than `48.0` unless you explicitly intend to clip it.
- If you *must* make it smaller, you must override the behavior: `materialTapTargetSize: MaterialTapTargetSize.shrinkWrap`.

## 2. Keyboard Compression (Bottom Sheets & Modals)
**The Issue:** When the on-screen keyboard opens, `MediaQuery.of(context).viewInsets.bottom` increases. If you dynamically shrink the height of a UI element (like a custom `showModalBottomSheet`) using `availableHeight - viewInsets.bottom`, the remaining height might approach zero on small screens or web browsers, causing the children (like TextFields) to throw a `RenderFlex` overflow.
**The Prevention:**
- **ALWAYS** provide a hard minimum height fallback when doing dynamic height math. 
- Example: `double target = availableHeight - keyboard; return Container(height: target > 400 ? target : 400);`
- Or, let Flutter handle it natively by trusting `Scaffold`'s `resizeToAvoidBottomInset` and avoiding double-padding.

## 3. The "Expanded inside Unbounded" Trap
**The Issue:** Using `Expanded` or `Flexible` requires the parent widget to have a bounded constraint in that axis.
**The Prevention:**
- **NEVER** place an `Expanded` inside a `ListView`, `SingleChildScrollView`, or a `Column` that is nested inside another scrollable widget.
- An `Expanded` inside a `Column` MUST have a parent with a fixed or constrained height (like `Container(height: ...)`, `SizedBox`, or `Expanded` itself).

## 4. Horizontal ListView Heights
**The Issue:** A `ListView(scrollDirection: Axis.horizontal)` requires a tightly bounded vertical height.
**The Prevention:**
- Always wrap a horizontal `ListView` in a `Container` or `SizedBox` with an explicit `height`.
- Ensure this explicit height accounts for margins, padding, and the `48px` Material tap target minimums of its children.

## 5. Text Overflows
**The Issue:** Dynamic text (names, IDs, descriptions) can grow unpredictably and break layouts if placed nakedly in a `Row`.
**The Prevention:**
- If text shares a `Row` with other widgets (like Icons or Buttons), **ALWAYS** wrap the `Text` (or its containing `Column`) in an `Expanded` or `Flexible`.
- Consider adding `overflow: TextOverflow.ellipsis` to text that might exceed its bounds.
