import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/visit.dart';
import '../providers/visit_provider.dart';
import '../theme/jalapao_theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Histórico de Hoje',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => context.read<VisitProvider>().exportCsv(),
              icon: const Icon(Icons.share, size: 20),
              label: const Text('EXPORTAR CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: JalapaoTheme.onPrimary,
                foregroundColor: JalapaoTheme.primaryDeep,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: Consumer<VisitProvider>(
        builder: (context, provider, _) {
          final visits = provider.historyVisits;

          if (visits.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.history,
                    size: 64,
                    color: JalapaoTheme.textFaint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma visita registrada hoje',
                    style: TextStyle(
                      color: JalapaoTheme.textMuted,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visits.length,
            itemBuilder: (context, index) {
              final visit = visits[index];
              return _buildHistoryCard(visit);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(Visit visit) {
    final timeFormat = DateFormat('HH:mm');
    final duration =
        visit.entryTime != null && visit.exitTime != null
            ? visit.exitTime!.difference(visit.entryTime!)
            : null;

    Color statusColor;
    String statusText;
    switch (visit.status) {
      case 'fila':
        statusColor = JalapaoTheme.info;
        statusText = 'NA FILA';
        break;
      case 'agua':
        statusColor = JalapaoTheme.warn;
        statusText = 'NA ÁGUA';
        break;
      default:
        statusColor = JalapaoTheme.textFaint;
        statusText = 'CONCLUÍDO';
    }

    return Card(
      color: JalapaoTheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: JalapaoTheme.outline),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${visit.paxQty}',
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        title: Text(
          'Chegada: ${timeFormat.format(visit.arrivalTime)}',
          style: const TextStyle(
            color: JalapaoTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          statusText,
          style: TextStyle(color: statusColor, fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetail(
                'Entrada',
                visit.entryTime != null
                    ? timeFormat.format(visit.entryTime!)
                    : '--:--',
              ),
              _buildDetail(
                'Saída',
                visit.exitTime != null
                    ? timeFormat.format(visit.exitTime!)
                    : '--:--',
              ),
              _buildDetail(
                'Permanência',
                duration != null ? '${duration.inMinutes} min' : '--',
              ),
              _buildDetail(
                'Sync',
                visit.isSynced ? 'OK' : 'Pendente',
                color: visit.isSynced ? JalapaoTheme.ok : JalapaoTheme.warn,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: JalapaoTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? JalapaoTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
