import { spawn } from "child_process";
import { TextDecoder } from "util";
import {
  workspace,
  window,
  ProgressLocation,
  Diagnostic,
  TextDocument,
  Range,
  DiagnosticSeverity,
  DiagnosticCollection,
} from "vscode";

interface DartDiagnostic {
  file: string;
  offset: number;
  length: number;
  message: string;
  severity: number;
}

export const reportDiagnostics = (
  root: string,
  diagnostics: DiagnosticCollection
) => {
  var spawned = false;
  const completer = new Completer<void>();

  window.withProgress(
    {
      location: ProgressLocation.Window,
      title: "bloc analyzer",
    },
    async (_) => {
      try {
        await completer.promise;
        window.setStatusBarMessage("✓ bloc analyzer");
      } catch (err) {
        window.showErrorMessage(`${err}`);
      }
    }
  );
  const lint = spawn("dart", [
    "/Users/felix/Development/playgrounds/dart_playground/bin/bloc.dart",
    root,
    "--watch",
  ]);
  const decoder = new TextDecoder();
  lint.stdout.on("data", async (data) => {
    if (!spawned) {
      spawned = true;
      completer.complete();
    }
    const decoded = decoder.decode(data);
    const diagnosticsJson = JSON.parse(decoded) as Record<
      string,
      DartDiagnostic[]
    >;

    for (let file in diagnosticsJson) {
      const results: Diagnostic[] = [];
      const document = await workspace.openTextDocument(file);
      const diagnosticsForFile = diagnosticsJson[file];
      for (let diagnostic of diagnosticsForFile) {
        const range = toRange(document, diagnostic.offset, diagnostic.length);
        results.push(
          new Diagnostic(
            range,
            diagnostic.message,
            toSeverity(diagnostic.severity)
          )
        );
      }
      diagnostics.set(document.uri, results);
    }
  });
};

function toRange(
  document: TextDocument,
  offset: number,
  length: number
): Range {
  return new Range(
    document.positionAt(offset),
    document.positionAt(offset + length)
  );
}

function toSeverity(value: number): DiagnosticSeverity {
  if (value == 1) {
    return DiagnosticSeverity.Warning;
  }
  if (value == 2) {
    return DiagnosticSeverity.Information;
  }
  if (value == 3) {
    return DiagnosticSeverity.Hint;
  }
  return DiagnosticSeverity.Error;
}

class Completer<T> {
  public readonly promise: Promise<T>;
  public complete!: (value: PromiseLike<T> | T) => void;
  public reject!: (reason?: any) => void;

  public constructor() {
    this.promise = new Promise<T>((resolve, reject) => {
      this.complete = resolve;
      this.reject = reject;
    });
  }
}
