import 'package:bloc_lint/bloc_lint.dart';

Future<void> main() async {
  final server = await BlocAnalysisServer().serve();
  print('Listening on port ${server.port}...');
}
