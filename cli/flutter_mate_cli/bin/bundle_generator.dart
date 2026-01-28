#!/usr/bin/env dart

/// Generates a single "mega" Dart file from flutter_mate packages.
///
/// This script:
/// 1. Parses all Dart files in flutter_mate and flutter_mate_types
/// 2. Analyzes imports to build a dependency graph
/// 3. Topologically sorts files
/// 4. Merges into a single library with no cross-package deps
///
/// Usage:
///   dart run bin/bundle_generator.dart
///   dart run bin/bundle_generator.dart --output path/to/output.dart

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  // Parse arguments
  String? outputPath;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--output' && i + 1 < args.length) {
      outputPath = args[i + 1];
    }
  }

  // Find package roots relative to this script
  final scriptDir = p.dirname(Platform.script.toFilePath());
  final cliRoot = p.normalize(p.join(scriptDir, '..'));
  final packagesRoot = p.normalize(p.join(cliRoot, '..', '..', 'packages'));
  final flutterMateRoot = p.join(packagesRoot, 'flutter_mate');
  final flutterMateTypesRoot = p.join(packagesRoot, 'flutter_mate_types');
  final flutterMateGenRoot = p.join(packagesRoot, 'flutter_mate_gen');

  print('CLI root: $cliRoot');
  print('flutter_mate: $flutterMateRoot');
  print('flutter_mate_types: $flutterMateTypesRoot');
  print('flutter_mate_gen: $flutterMateGenRoot');

  outputPath ??= p.join(flutterMateGenRoot, 'lib', 'flutter_mate_gen.dart');

  final generator = BundleGenerator(
    flutterMateRoot: flutterMateRoot,
    flutterMateTypesRoot: flutterMateTypesRoot,
  );

  final bundleContent = await generator.generate();

  // Write output
  final outputFile = File(outputPath);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(bundleContent);

  print('\n✅ Bundle generated: $outputPath');
  print('   ${bundleContent.split('\n').length} lines');
}

class BundleGenerator {
  final String flutterMateRoot;
  final String flutterMateTypesRoot;

  /// All discovered source files
  final Map<String, SourceFile> _sourceFiles = {};

  /// Resolved import graph (file -> files it depends on)
  final Map<String, Set<String>> _dependencies = {};

  /// External Flutter/Dart imports to collect (uri -> full import line)
  final Map<String, String> _externalImports = {};

  BundleGenerator({
    required this.flutterMateRoot,
    required this.flutterMateTypesRoot,
  });

  Future<String> generate() async {
    // Step 1: Discover all source files
    print('\n📁 Discovering source files...');
    await _discoverFiles();
    print('   Found ${_sourceFiles.length} files');

    // Step 2: Analyze imports and build dependency graph
    print('\n🔍 Analyzing imports...');
    _analyzeImports();
    print('   Found ${_externalImports.length} external imports:');
    for (final imp in _externalImports.values) {
      print('     $imp');
    }

    // Step 3: Topologically sort files
    print('\n📊 Topologically sorting...');
    final sortedFiles = _topologicalSort();
    print('   Order: ${sortedFiles.map((f) => p.basename(f)).join(' → ')}');

    // Step 4: Generate the merged bundle
    print('\n📝 Generating bundle...');
    return _generateBundle(sortedFiles);
  }

  Future<void> _discoverFiles() async {
    // Discover flutter_mate_types files
    await _discoverFilesInDir(
      Directory(p.join(flutterMateTypesRoot, 'lib')),
      'package:flutter_mate_types',
    );

    // Discover flutter_mate files (excluding generated bundles and facade files)
    await _discoverFilesInDir(
      Directory(p.join(flutterMateRoot, 'lib')),
      'package:flutter_mate',
      exclude: [
        'flutter_mate_bundle.dart', // Generated bundle
      ],
      excludePaths: [
        'src/flutter_mate.dart', // Facade file that uses import aliases
      ],
    );
  }

  Future<void> _discoverFilesInDir(
    Directory dir,
    String packageUri, {
    List<String> exclude = const [],
    List<String> excludePaths = const [],
  }) async {
    if (!await dir.exists()) {
      print('   Warning: Directory not found: ${dir.path}');
      return;
    }

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final fileName = p.basename(entity.path);

        // Skip excluded files by name
        if (exclude.contains(fileName)) {
          continue;
        }

        final relativePath =
            p.relative(entity.path, from: p.join(dir.path, '..', 'lib'));

        // Skip excluded files by path
        if (excludePaths.contains(relativePath)) {
          print('   Skipping facade: $relativePath');
          continue;
        }

        final uri = '$packageUri/$relativePath';

        _sourceFiles[uri] = SourceFile(
          uri: uri,
          path: entity.path,
          content: await entity.readAsString(),
        );
      }
    }
  }

  void _analyzeImports() {
    for (final file in _sourceFiles.values) {
      _dependencies[file.uri] = {};

      final parseResult = parseString(content: file.content);
      final unit = parseResult.unit;

      for (final directive in unit.directives) {
        if (directive is ImportDirective) {
          final importUri = directive.uri.stringValue ?? '';

          if (importUri.startsWith('package:flutter_mate_types/') ||
              importUri.startsWith('package:flutter_mate/')) {
            // Internal import - add to dependency graph
            _dependencies[file.uri]!.add(importUri);
          } else if (importUri.startsWith('dart:') ||
              importUri.startsWith('package:flutter/') ||
              importUri.startsWith('package:')) {
            // External import - collect for the bundle header
            // Preserve the full import line including aliases and show/hide
            final importLine = _extractImportLine(directive, importUri);

            // Use uri as key, but if we already have it with an alias, keep that
            if (!_externalImports.containsKey(importUri) ||
                importLine.contains(' as ')) {
              _externalImports[importUri] = importLine;
            }
          } else if (importUri.startsWith("'") || importUri.contains('/')) {
            // Relative import - resolve to absolute
            final resolved = _resolveRelativeImport(file.uri, importUri);
            if (resolved != null) {
              _dependencies[file.uri]!.add(resolved);
            }
          }
        }

        // Handle exports too
        if (directive is ExportDirective) {
          final exportUri = directive.uri.stringValue ?? '';

          if (exportUri.startsWith('package:flutter_mate_types/') ||
              exportUri.startsWith('package:flutter_mate/')) {
            // Internal export - treat as dependency
            _dependencies[file.uri]!.add(exportUri);
          }
        }
      }
    }
  }

  String _extractImportLine(ImportDirective directive, String uri) {
    final buffer = StringBuffer("import '$uri'");

    // Add alias if present
    if (directive.prefix != null) {
      buffer.write(' as ${directive.prefix!.name}');
    }

    // Add show/hide combinators
    for (final combinator in directive.combinators) {
      if (combinator is ShowCombinator) {
        buffer.write(' show ');
        buffer.write(combinator.shownNames.map((n) => n.name).join(', '));
      } else if (combinator is HideCombinator) {
        buffer.write(' hide ');
        buffer.write(combinator.hiddenNames.map((n) => n.name).join(', '));
      }
    }

    buffer.write(';');
    return buffer.toString();
  }

  String? _resolveRelativeImport(String fromUri, String relativeImport) {
    // Handle relative imports like '../core/flutter_mate.dart'
    final fromParts = fromUri.split('/');
    final basePath = fromParts.sublist(0, fromParts.length - 1).join('/');

    // Simple path resolution
    final segments = '$basePath/$relativeImport'.split('/');
    final resolved = <String>[];

    for (final segment in segments) {
      if (segment == '..') {
        if (resolved.isNotEmpty) resolved.removeLast();
      } else if (segment != '.' && segment.isNotEmpty) {
        resolved.add(segment);
      }
    }

    final resolvedUri = resolved.join('/');
    return _sourceFiles.containsKey(resolvedUri) ? resolvedUri : null;
  }

  List<String> _topologicalSort() {
    final sorted = <String>[];
    final visited = <String>{};
    final visiting = <String>{};

    void visit(String uri) {
      if (visited.contains(uri)) return;
      if (visiting.contains(uri)) {
        // Circular dependency - just continue
        return;
      }

      visiting.add(uri);

      for (final dep in _dependencies[uri] ?? <String>{}) {
        if (_sourceFiles.containsKey(dep)) {
          visit(dep);
        }
      }

      visiting.remove(uri);
      visited.add(uri);
      sorted.add(uri);
    }

    // Start with types package (it has no internal deps)
    for (final uri in _sourceFiles.keys) {
      if (uri.startsWith('package:flutter_mate_types/')) {
        visit(uri);
      }
    }

    // Then flutter_mate package
    for (final uri in _sourceFiles.keys) {
      if (uri.startsWith('package:flutter_mate/')) {
        visit(uri);
      }
    }

    return sorted;
  }

  String _generateBundle(List<String> sortedFiles) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(
        '/// Flutter Mate Bundle - Auto-generated single-file library');
    buffer.writeln('///');
    buffer.writeln(
        '/// This file combines flutter_mate and flutter_mate_types into a single');
    buffer.writeln(
        '/// library that compiles to a single JS module for web injection.');
    buffer.writeln('///');
    buffer.writeln('/// Generated by: dart run bin/bundle_generator.dart');
    buffer.writeln('/// Date: ${DateTime.now().toIso8601String()}');
    buffer.writeln('///');
    buffer.writeln('/// DO NOT EDIT - regenerate instead.');
    buffer.writeln('library flutter_mate_gen;');
    buffer.writeln();

    // External imports (sorted and deduplicated, preserving aliases)
    final sortedUris = _externalImports.keys.toList()..sort();

    // Skip redundant imports (re-exported by other imports)
    const redundantImports = {
      'dart:typed_data', // Re-exported by flutter/services.dart
    };

    for (final uri in sortedUris) {
      // Skip internal package imports
      if (uri.startsWith('package:flutter_mate')) continue;
      // Skip redundant imports
      if (redundantImports.contains(uri)) continue;
      buffer.writeln(_externalImports[uri]);
    }
    buffer.writeln();

    // Process each file
    for (final uri in sortedFiles) {
      final file = _sourceFiles[uri];
      if (file == null) continue;

      // Skip barrel files (they just re-export)
      if (_isBarrelFile(file.content)) {
        continue;
      }

      buffer.writeln(
          '// ════════════════════════════════════════════════════════════════════════════');
      buffer.writeln('// Source: $uri');
      buffer.writeln(
          '// ════════════════════════════════════════════════════════════════════════════');
      buffer.writeln();

      final processedContent = _processFileContent(file.content);
      buffer.writeln(processedContent);
      buffer.writeln();
    }

    return buffer.toString();
  }

  bool _isBarrelFile(String content) {
    // A barrel file only contains exports, library directive, and comments
    final parseResult = parseString(content: content);
    final unit = parseResult.unit;

    bool hasExports = false;
    bool hasNonExportDeclarations = false;

    for (final directive in unit.directives) {
      if (directive is ExportDirective) {
        hasExports = true;
      } else if (directive is ImportDirective) {
        // Has imports beyond just exports
        final uri = directive.uri.stringValue ?? '';
        if (!uri.startsWith('package:flutter_mate')) {
          // External import means this isn't just a barrel
          hasNonExportDeclarations = true;
        }
      }
    }

    // Check for actual declarations (classes, functions, etc.)
    if (unit.declarations.isNotEmpty) {
      hasNonExportDeclarations = true;
    }

    return hasExports && !hasNonExportDeclarations;
  }

  String _processFileContent(String content) {
    final lines = content.split('\n');
    final outputLines = <String>[];
    var inMultiLineComment = false;

    for (var line in lines) {
      // Track multi-line comments
      if (line.contains('/*')) inMultiLineComment = true;
      if (line.contains('*/')) inMultiLineComment = false;

      // Skip library directives
      if (line.trim().startsWith('library')) continue;

      // Skip internal imports/exports
      if (_isInternalImportOrExport(line)) continue;

      // Skip external imports (they're in the header)
      if (_isExternalImport(line) && !inMultiLineComment) continue;

      // Keep everything else
      outputLines.add(line);
    }

    // Remove excessive blank lines
    final result = <String>[];
    var prevWasBlank = false;
    for (final line in outputLines) {
      final isBlank = line.trim().isEmpty;
      if (isBlank && prevWasBlank) continue;
      result.add(line);
      prevWasBlank = isBlank;
    }

    return result.join('\n').trim();
  }

  bool _isInternalImportOrExport(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('import ') && !trimmed.startsWith('export ')) {
      return false;
    }
    return trimmed.contains('package:flutter_mate_types') ||
        trimmed.contains('package:flutter_mate/') ||
        // Also skip relative imports within the package
        (trimmed.contains("'../") || trimmed.contains("'./"));
  }

  bool _isExternalImport(String line) {
    final trimmed = line.trim();
    return trimmed.startsWith('import ') || trimmed.startsWith('export ');
  }
}

class SourceFile {
  final String uri;
  final String path;
  final String content;

  SourceFile({
    required this.uri,
    required this.path,
    required this.content,
  });
}
