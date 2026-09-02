import 'dart:convert';
import 'dart:io';

void main() {
  final stateFile = File('project-state.json');
  if (!stateFile.existsSync()) {
    stderr.writeln('project-state.json is missing');
    exitCode = 1;
    return;
  }

  final state = jsonDecode(stateFile.readAsStringSync());
  if (state is! Map<String, dynamic>) {
    stderr.writeln('project-state.json must contain an object');
    exitCode = 1;
    return;
  }

  const expected = <String, Object>{
    'project': 'AVORA',
    'repository': 'officialavora/AVORA',
    'androidPackage': 'com.officialavora.app',
    'funnyRoomMutationAllowed': false,
    'paidServiceActivationAllowed': false,
  };

  for (final entry in expected.entries) {
    if (state[entry.key] != entry.value) {
      stderr.writeln('${entry.key} has an unsafe or unexpected value');
      exitCode = 1;
      return;
    }
  }

  final exclusions = state['excludedModules'];
  if (exclusions is! List ||
      !exclusions.contains('voice_rtc') ||
      !exclusions.contains('money_recharge')) {
    stderr.writeln('Scope exclusions are missing');
    exitCode = 1;
    return;
  }

  stdout.writeln('AVORA_PROJECT_STATE_OK');
}
