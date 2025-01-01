// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:bloc_lint/src/diagnostics.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

class BlocAnalysisServer {
  BlocAnalysisServer();

  AnalysisContextCollection? collection;

  Future<HttpServer> serve({InternetAddress? address, int port = 80}) async {
    final router = _createRouter();
    return shelf_io.serve(
      router.call,
      address ?? InternetAddress.anyIPv6,
      port,
    );
  }

  Router _createRouter() {
    return Router()..post('/diagnostics', _onDiagnostics);
  }

  Future<Response> _onDiagnostics(Request request) async {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final root = body['root'] as String;
    final diagnosticsAnalyzer = BlocDiagnostics(root: root);
    collection = AnalysisContextCollection(
      includedPaths: [root],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );
    final diagnostics = await diagnosticsAnalyzer.analyze();
    final json = {
      for (final entry in diagnostics.entries)
        entry.key: entry.value.map((d) => d.toJson()).toList(),
    };

    return Response.ok(
      jsonEncode(json),
      headers: {'content-type': 'application/json'},
    );
  }
}
