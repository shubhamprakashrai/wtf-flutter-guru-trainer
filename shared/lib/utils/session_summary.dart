import '../models/session_log.dart';
import 'time_ext.dart';

/// Plain-text summary for the "Export (bonus): share text summary" item in
/// spec section 3.E, shared by both apps' session-log detail sheets.
String sessionSummaryText(SessionLog log, {required String memberName, required String trainerName}) {
  final buffer = StringBuffer()
    ..writeln('WTF Session Summary')
    ..writeln('--------------------')
    ..writeln('Member: $memberName')
    ..writeln('Trainer: $trainerName')
    ..writeln('Date: ${log.startedAt.day}/${log.startedAt.month}/${log.startedAt.year} '
        '${log.startedAt.hour}:${log.startedAt.minute.toString().padLeft(2, '0')}')
    ..writeln('Duration: ${log.durationSec.asDuration}');

  if (log.rating != null) {
    buffer.writeln('Rating: ${log.rating}/5');
  }
  if (log.memberNotes != null && log.memberNotes!.isNotEmpty) {
    buffer.writeln('Member note: ${log.memberNotes}');
  }
  if (log.trainerNotes != null && log.trainerNotes!.isNotEmpty) {
    buffer.writeln('Trainer note: ${log.trainerNotes}');
  }

  return buffer.toString();
}
