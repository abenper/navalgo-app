import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/time_entry.dart';
import '../../services/time_tracking_service.dart';
import '../../viewmodels/session_view_model.dart';

class FichajeScreen extends StatefulWidget {
  const FichajeScreen({super.key});

  @override
  State<FichajeScreen> createState() => _FichajeScreenState();
}

class _FichajeScreenState extends State<FichajeScreen> {
  bool _isLoading = true;
  String? _error;
  bool _isPunchedIn = false;
  List<TimeEntry> _entries = <TimeEntry>[];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final session = context.read<SessionViewModel>();
    final token = session.token;
    final workerId = session.user?.id;

    if (token == null || workerId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Sesion no valida';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final entries = await context.read<TimeTrackingService>().getByWorker(
            token,
            workerId: workerId,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
        _isPunchedIn = entries.any((e) => e.clockOut == null);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleClock() async {
    final session = context.read<SessionViewModel>();
    final token = session.token;
    final workerId = session.user?.id;

    if (token == null || workerId == null) {
      return;
    }

    try {
      if (_isPunchedIn) {
        await context.read<TimeTrackingService>().clockOut(token, workerId: workerId);
      } else {
        await context.read<TimeTrackingService>().clockIn(token, workerId: workerId);
      }
      await _loadEntries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo fichar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text(_error!)),
        floatingActionButton: FloatingActionButton(
          onPressed: _loadEntries,
          child: const Icon(Icons.refresh),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isPunchedIn ? Icons.timer : Icons.timer_off,
              size: 100,
              color: _isPunchedIn ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              _isPunchedIn ? 'Estado: Trabajando' : 'Estado: Fuera de turno',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                backgroundColor:
                    _isPunchedIn ? Colors.red.shade700 : Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _toggleClock,
              icon: Icon(_isPunchedIn ? Icons.stop : Icons.play_arrow),
              label: Text(
                _isPunchedIn ? 'Finalizar Turno' : 'Iniciar Turno',
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Ultimos registros', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              width: 420,
              height: 180,
              child: ListView.builder(
                itemCount: _entries.length > 4 ? 4 : _entries.length,
                itemBuilder: (context, index) {
                  final item = _entries[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        item.clockOut == null ? Icons.login : Icons.logout,
                        color: item.clockOut == null ? Colors.green : Colors.red,
                      ),
                      title: Text(item.clockOut == null ? 'Entrada' : 'Jornada cerrada'),
                      subtitle: Text('In: ${_fmt(item.clockIn)}'),
                      trailing: Text(item.clockOut == null ? '--' : _fmt(item.clockOut!)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final mo = d.month.toString().padLeft(2, '0');
    return '$dd/$mo $hh:$mm';
  }
}
