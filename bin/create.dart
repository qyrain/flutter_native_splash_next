import 'package:args/args.dart';
import 'package:flutter_native_splash_next/cli_commands.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'path',
      abbr: 'p',
      help: 'Path to the YAML configuration file (defaults to flutter_native_splash_next.yaml or pubspec.yaml).',
    )
    ..addOption(
      'flavor',
      abbr: 'f',
      help: 'Flavor name to generate splash screens for.',
    );

  final results = parser.parse(args);
  await createSplash(
    path: results['path'] as String?,
    flavor: results['flavor'] as String?,
  );
}
