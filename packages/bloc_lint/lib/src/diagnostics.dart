// ignore_for_file: public_member_api_docs

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/file_system/physical_file_system.dart';

enum Severity {
  info,
  warning,
  error,
}

class Diagnostic {
  const Diagnostic({
    required this.file,
    required this.severity,
    required this.code,
    required this.message,
    required this.offset,
    required this.length,
  });

  final String file;
  final int severity;
  final String code;
  final String message;
  final int offset;
  final int length;

  @override
  int get hashCode =>
      Object.hashAll([file, severity, code, message, offset, length]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Diagnostic) return false;
    return file == other.file &&
        severity == other.severity &&
        code == other.code &&
        message == other.message &&
        offset == other.offset &&
        length == other.length;
  }

  Map<String, dynamic> toJson() {
    return {
      'file': file,
      'severity': severity,
      'code': code,
      'message': message,
      'offset': offset,
      'length': length,
    };
  }
}

abstract class BlocDiagnosticVisitor extends GeneralizingAstVisitor<void> {
  BlocDiagnosticVisitor({required this.file});

  List<Diagnostic> diagnostics = [];
  final String file;
}

class PreferCubitVisitor extends BlocDiagnosticVisitor {
  PreferCubitVisitor({required super.file});

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (node.extendsClause?.superclass.name2.toString() == 'Bloc') {
      diagnostics.add(
        Diagnostic(
          file: file,
          offset: node.name.offset,
          length: node.name.length,
          code: node.toSource(),
          message:
              '''class ${node.name} should extend Cubit instead of Bloc (prefer_cubit).''',
          severity: 1,
        ),
      );
    }
    return super.visitClassDeclaration(node);
  }
}

class BlocDiagnostics {
  BlocDiagnostics({required String root}) {
    collection = AnalysisContextCollection(
      includedPaths: [root],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );
  }

  late final AnalysisContextCollection collection;

  Future<Map<String, Set<Diagnostic>>> analyze({String? file}) async {
    final diagnostics = <String, Set<Diagnostic>>{};
    final visitors = [
      (String file) => PreferCubitVisitor(file: file),
    ];

    for (final context in collection.contexts) {
      for (final filePath in context.contextRoot.analyzedFiles()) {
        if (file != null && filePath != file) continue;
        if (!diagnostics.containsKey(filePath)) diagnostics[filePath] = {};
        final unit = await context.currentSession.getResolvedUnit(filePath);
        if (unit is ResolvedUnitResult) {
          for (final visitor in visitors) {
            final v = visitor(filePath);
            unit.unit.visitChildren(v);
            diagnostics[filePath]!.addAll(v.diagnostics);
          }
        }
      }
    }
    return diagnostics;
  }
}
