import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../auth/domain/auth_provider.dart';
import '../viewer/bim_viewer_contract.dart';
import 'bim_realtime_panel.dart';
import 'bim_realtime_viewer.dart';
import 'bim_session_coordinator.dart';
import 'bim_session_models.dart';
import 'dio_bim_session_api.dart';

class BimRealtimeSection extends ConsumerStatefulWidget {
  const BimRealtimeSection({
    super.key,
    required this.projectId,
    required this.document,
    required this.controller,
    required this.offline,
  });

  final int projectId;
  final BimViewerDocument document;
  final BimViewerController controller;
  final bool offline;

  @override
  ConsumerState<BimRealtimeSection> createState() => _BimRealtimeSectionState();
}

class _BimRealtimeSectionState extends ConsumerState<BimRealtimeSection> {
  BimSessionCoordinator? _coordinator;
  List<BimSessionSummary> _sessions = const [];
  bool _loading = false;
  bool _canCreate = false;
  Object? _error;
  int _operation = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    final user = ref.read(authProvider).user;
    if (user == null || widget.document.modelSetRevisionId == null) return;
    _coordinator = BimSessionCoordinator(
      api: ref.read(bimSessionApiProvider),
      viewer: BimRealtimeViewerAdapter(widget.controller),
      userId: user.serverId,
      userName: user.name,
    );
    _coordinator!.setOnline(!widget.offline);
    if (!widget.offline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }
  }

  @override
  void didUpdateWidget(BimRealtimeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.projectId != widget.projectId ||
        oldWidget.document.modelSetRevisionId !=
            widget.document.modelSetRevisionId) {
      ++_operation;
      _coordinator?.dispose();
      _coordinator = null;
      _sessions = const [];
      _canCreate = false;
      _loading = false;
      _error = null;
      _initialize();
    } else if (oldWidget.offline != widget.offline) {
      _coordinator?.setOnline(!widget.offline);
      if (!widget.offline) _refresh();
    }
  }

  Future<void> _refresh() async {
    final revisionId = widget.document.modelSetRevisionId;
    if (widget.offline || revisionId == null) return;
    final operation = ++_operation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(bimSessionApiProvider)
          .listSessions(widget.projectId, revisionId);
      if (mounted && operation == _operation && !widget.offline) {
        setState(() {
          _sessions = page.sessions;
          _canCreate = page.canCreate;
        });
      }
    } catch (error) {
      if (mounted && operation == _operation) setState(() => _error = error);
    } finally {
      if (mounted && operation == _operation) setState(() => _loading = false);
    }
  }

  Future<void> _create(String title) async {
    if (widget.offline || !_canCreate || _loading) return;
    final operation = ++_operation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await ref
          .read(bimSessionApiProvider)
          .createSession(
            projectId: widget.projectId,
            modelSetRevisionId: widget.document.modelSetRevisionId!,
            title: title,
          );
      if (!mounted || operation != _operation || widget.offline) return;
      setState(() => _sessions = [session, ..._sessions]);
      await _coordinator?.join(session);
    } catch (error) {
      if (mounted && operation == _operation) setState(() => _error = error);
    } finally {
      if (mounted && operation == _operation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = _coordinator;
    if (coordinator == null) return const SizedBox.shrink();
    return BimRealtimePanel(
      coordinator: coordinator,
      sessions: _sessions,
      isLoading: _loading,
      offline: widget.offline,
      canCreate: _canCreate,
      error: _error,
      onRefresh: _refresh,
      onCreate: _create,
      onJoin: coordinator.join,
    );
  }

  @override
  void dispose() {
    ++_operation;
    _coordinator?.dispose();
    super.dispose();
  }
}
