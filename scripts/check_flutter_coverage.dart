import 'dart:io';

const lcovPath = 'coverage/lcov.info';
const globalThreshold = 70.0;
const securityThreshold = 90.0;

// Dart-side security surface for the mobile app. Backend auth/RLS/RPC/storage
// enforcement is covered by pgTAP in `supabase test db`; these files cover
// the client flows where security-sensitive decisions are surfaced to users.
const securityFiles = <String>{
  'lib/ui/features/auth/lgpd_consent_screen.dart',
  'lib/ui/features/auth/login_screen.dart',
  'lib/ui/features/invite/accept_invite_screen.dart',
  'lib/ui/features/invite/invite_screen.dart',
  'lib/ui/features/profile/delete_account_screen.dart',
  'lib/ui/features/profile/export_data_screen.dart',
  'lib/ui/features/profile/profile_screen.dart',
  'lib/ui/features/profile/transfer_ownership_screen.dart',
};

void main() {
  final file = File(lcovPath);
  if (!file.existsSync()) {
    stderr.writeln('Coverage file not found: $lcovPath');
    exitCode = 1;
    return;
  }

  final global = _Coverage();
  final security = _Coverage();
  final securityByFile = <String, _Coverage>{};

  String? currentFile;
  var current = _Coverage();

  void finishRecord() {
    final path = currentFile;
    if (path == null) return;

    global.add(current);
    if (securityFiles.contains(path)) {
      security.add(current);
      securityByFile[path] = current.copy();
    }
  }

  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      finishRecord();
      currentFile = _normalizePath(line.substring(3));
      current = _Coverage();
      continue;
    }
    if (line.startsWith('LF:')) {
      current.found += int.parse(line.substring(3));
      continue;
    }
    if (line.startsWith('LH:')) {
      current.hit += int.parse(line.substring(3));
      continue;
    }
    if (line == 'end_of_record') {
      finishRecord();
      currentFile = null;
      current = _Coverage();
    }
  }
  finishRecord();

  final missing = securityFiles.difference(securityByFile.keys.toSet());
  if (missing.isNotEmpty) {
    stderr.writeln('Security coverage files missing from $lcovPath:');
    for (final path in missing.toList()..sort()) {
      stderr.writeln('- $path');
    }
    exitCode = 1;
    return;
  }

  _printCoverage('Global', global);
  stdout.writeln('Security modules:');
  for (final entry
      in securityByFile.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key))) {
    _printCoverage('  ${entry.key}', entry.value);
  }
  _printCoverage('Security total', security);

  var failed = false;
  if (global.percent < globalThreshold) {
    stderr.writeln(
      'Global coverage ${global.percentText} is below '
      '${globalThreshold.toStringAsFixed(2)}%.',
    );
    failed = true;
  }
  if (security.percent < securityThreshold) {
    stderr.writeln(
      'Security coverage ${security.percentText} is below '
      '${securityThreshold.toStringAsFixed(2)}%.',
    );
    failed = true;
  }
  if (failed) {
    exitCode = 1;
  }
}

String _normalizePath(String value) {
  final slashPath = value.replaceAll(r'\', '/');
  final libIndex = slashPath.indexOf('/lib/');
  if (libIndex >= 0) return slashPath.substring(libIndex + 1);
  if (slashPath.startsWith('lib/')) return slashPath;
  return slashPath;
}

void _printCoverage(String label, _Coverage coverage) {
  stdout.writeln(
    '$label: ${coverage.percentText} '
    '(${coverage.hit}/${coverage.found})',
  );
}

class _Coverage {
  int hit = 0;
  int found = 0;

  double get percent => found == 0 ? 0 : hit * 100 / found;
  String get percentText => '${percent.toStringAsFixed(2)}%';

  void add(_Coverage other) {
    hit += other.hit;
    found += other.found;
  }

  _Coverage copy() {
    return _Coverage()
      ..hit = hit
      ..found = found;
  }
}
