import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:getman/core/domain/persistence_limits.dart';
import 'package:getman/core/theme/app_theme.dart';
import 'package:getman/core/utils/json_utils.dart';
import 'package:getman/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:getman/features/settings/presentation/bloc/settings_state.dart';
import 'package:getman/features/tabs/domain/entities/request_tab_entity.dart';
import 'package:getman/features/tabs/presentation/bloc/tabs_bloc.dart';
import 'package:getman/features/tabs/presentation/bloc/tabs_state.dart';
import 'package:getman/features/tabs/presentation/widgets/json_code_editor.dart';
import 'package:getman/features/tabs/presentation/widgets/response/response_body_controls.dart';
import 'package:getman/features/tabs/presentation/widgets/response/response_large_body_view.dart';
import 'package:re_editor/re_editor.dart';

/// BODY tab: renders the response body. Sub-threshold bodies go through a
/// Pretty/Raw toggle + the JSON editor; bodies over [kLargeResponseViewerChars]
/// fall back to a plain-text viewer (unless the user opts into highlighting).
class ResponseBodyView extends StatefulWidget {
  const ResponseBodyView({
    required this.tabId,
    required this.responseController,
    super.key,
  });
  final String tabId;
  final CodeLineEditingController responseController;

  @override
  State<ResponseBodyView> createState() => _ResponseBodyViewState();
}

class _ResponseBodyViewState extends State<ResponseBodyView> {
  int _pendingSyncId = 0;

  // Pretty (prettified JSON) vs Raw (verbatim body). Applies to the normal,
  // sub-threshold path; the large-response banner has its own controls.
  bool _raw = false;

  // Large-mode state: non-null when the current body exceeds the threshold.
  String? _largeBody;
  bool _showFullPreview = false;
  bool _highlightingOptedIn = false;

  @override
  void initState() {
    super.initState();
    final tab = context.read<TabsBloc>().state.tabs.byId(widget.tabId);
    unawaited(_syncBody(tab?.response?.body));
  }

  Future<void> _syncBody(String? rawBody) async {
    final syncId = ++_pendingSyncId;

    if (rawBody != null && rawBody.length > kLargeResponseViewerChars) {
      // Opt-in setting: prettify + highlight large bodies automatically (the
      // user accepts the render cost). The over-1-MB placeholder is a known
      // non-JSON sentinel, so it always stays in plain-text mode.
      final autoPrettify =
          context
              .read<SettingsBloc>()
              .state
              .settings
              .alwaysPrettifyLargeResponses &&
          rawBody != kResponseBodyTooLargePlaceholder;
      if (autoPrettify) {
        final prettified = await JsonUtils.prettify(rawBody);
        if (!mounted || syncId != _pendingSyncId) return;
        widget.responseController.text = prettified;
        setState(() {
          _largeBody = rawBody;
          _showFullPreview = false;
          _highlightingOptedIn = true;
        });
        return;
      }
      // Large path — skip prettify and editor; go to plain-text mode.
      if (!mounted || syncId != _pendingSyncId) return;
      setState(() {
        _largeBody = rawBody;
        _showFullPreview = false;
        _highlightingOptedIn = false;
      });
      return;
    }

    // Normal path — prettify (or pass through verbatim in raw mode), then load
    // into the editor. The over-1-MB sentinel is known non-JSON, so render it
    // as plain text rather than spawning an isolate to fail-parse it.
    final text = (_raw || rawBody == kResponseBodyTooLargePlaceholder)
        ? (rawBody ?? '')
        : await JsonUtils.prettify(rawBody);
    // Only apply if no newer sync was started and we're still mounted.
    if (!mounted || syncId != _pendingSyncId) return;
    widget.responseController.text = text;
    // Clear large mode if a previous response triggered it.
    if (_largeBody != null) {
      setState(() {
        _largeBody = null;
        _showFullPreview = false;
        _highlightingOptedIn = false;
      });
    }
  }

  void _setRaw(bool raw) {
    if (_raw == raw) return;
    setState(() => _raw = raw);
    final body = context
        .read<TabsBloc>()
        .state
        .tabs
        .byId(widget.tabId)
        ?.response
        ?.body;
    unawaited(_syncBody(body));
  }

  Future<void> _prettifyAndOptIn() async {
    final body = _largeBody;
    if (body == null) return;
    final syncId = ++_pendingSyncId;
    final prettified = await JsonUtils.prettify(body);
    if (!mounted || syncId != _pendingSyncId) return;
    widget.responseController.text = prettified;
    setState(() => _highlightingOptedIn = true);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TabsBloc, TabsState>(
          listenWhen: (prev, next) {
            final prevTab = prev.tabs.byId(widget.tabId);
            final nextTab = next.tabs.byId(widget.tabId);
            return prevTab?.response?.body != nextTab?.response?.body;
          },
          listener: (context, state) {
            final tab = state.tabs.byId(widget.tabId);
            unawaited(_syncBody(tab?.response?.body));
          },
        ),
        // Re-render the current body when the user flips the prettify-large
        // setting, so the change is visible without re-sending.
        BlocListener<SettingsBloc, SettingsState>(
          listenWhen: (prev, next) =>
              prev.settings.alwaysPrettifyLargeResponses !=
              next.settings.alwaysPrettifyLargeResponses,
          listener: (context, state) {
            final body = context
                .read<TabsBloc>()
                .state
                .tabs
                .byId(widget.tabId)
                ?.response
                ?.body;
            unawaited(_syncBody(body));
          },
        ),
      ],
      child: _largeBody != null ? _buildLargeMode() : _buildSmallMode(),
    );
  }

  /// The text a Copy action should put on the clipboard: the verbatim large
  /// body when highlighting is off, otherwise whatever the editor shows.
  String _copyableText() => _largeBody != null && !_highlightingOptedIn
      ? _largeBody!
      : widget.responseController.text;

  /// Sub-threshold view: a Pretty/Raw toggle (+ copy) above the editor.
  Widget _buildSmallMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _PrettyRawToggle(raw: _raw, onChanged: _setRaw),
            ),
            ResponseBodyControls(
              tabId: widget.tabId,
              getCopyableText: _copyableText,
            ),
          ],
        ),
        Expanded(child: _buildEditorMode()),
      ],
    );
  }

  Widget _buildEditorMode() {
    return SizedBox(
      width: double.infinity,
      child: JsonCodeEditor(
        controller: widget.responseController,
        readOnly: true,
        wordWrap: !_highlightingOptedIn,
      ),
    );
  }

  Widget _buildLargeMode() {
    final palette = context.appPalette;
    final typography = context.appTypography;
    final layout = context.appLayout;
    final theme = Theme.of(context);
    final body = _largeBody!;
    final displayText = _showFullPreview
        ? body
        : body.substring(0, body.length.clamp(0, kLargeResponsePreviewChars));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner row — extracted to ResponseLargeBodyView.
        ResponseLargeBodyView(
          body: body,
          showFullPreview: _showFullPreview,
          highlightingOptedIn: _highlightingOptedIn,
          onPrettifyAndOptIn: _prettifyAndOptIn,
          onShowFull: () => setState(() => _showFullPreview = true),
          controls: ResponseBodyControls(
            tabId: widget.tabId,
            getCopyableText: _copyableText,
          ),
        ),
        // Body — editor when opted-in, plain text otherwise. Kept here so the
        // editor widget occupies the same Column.children[1] position in both
        // small and large mode, preventing re_editor state teardown on switch.
        Expanded(
          child: _highlightingOptedIn
              ? _buildEditorMode()
              : ColoredBox(
                  color: palette.codeBackground,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(layout.pagePadding),
                    child: SelectableText(
                      displayText,
                      style: TextStyle(
                        fontFamily: typography.codeFontFamily,
                        fontSize: layout.fontSizeCode,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PrettyRawToggle extends StatelessWidget {
  const _PrettyRawToggle({required this.raw, required this.onChanged});
  final bool raw;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final layout = context.appLayout;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: layout.pagePadding,
        vertical: layout.isCompact ? 4 : 6,
      ),
      child: Row(
        children: [
          _seg(context, 'PRETTY', !raw, () => onChanged(false)),
          SizedBox(width: layout.tabSpacing),
          _seg(context, 'RAW', raw, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _seg(
    BuildContext context,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final layout = context.appLayout;
    final activeBg = context.appPalette.selectorActive;
    final activeIsDark =
        ThemeData.estimateBrightnessForColor(activeBg) == Brightness.dark;
    // Deliberate contrast: a readable foreground picked from the dynamic,
    // theme-derived `activeBg` brightness (CLAUDE.md §4.8 exception) — not a
    // themeable surface color.
    // ignore: avoid_hardcoded_brand_colors
    final onActive = activeIsDark ? Colors.white : Colors.black;
    return context.appDecoration.wrapInteractive(
      onTap: onTap,
      child: Container(
        key: ValueKey('body_toggle_$label'),
        padding: EdgeInsets.symmetric(
          horizontal: layout.badgePaddingHorizontal + 4,
          vertical: layout.badgePaddingVertical + 2,
        ),
        decoration: BoxDecoration(
          color: active ? activeBg : Colors.transparent,
          border: Border.all(
            color: theme.dividerColor,
            width: layout.borderThin,
          ),
          borderRadius: BorderRadius.circular(context.appShape.buttonRadius),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: layout.fontSizeSmall,
            fontWeight: context.appTypography.displayWeight,
            color: active ? onActive : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
