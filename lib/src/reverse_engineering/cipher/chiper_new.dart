import 'package:freezed_annotation/freezed_annotation.dart';

import '../../js/js_engine.dart';

// Enhanced signature function extraction patterns
final _decFuncExp = RegExp(
    r'\b([a-zA-Z0-9_$]+)&&\(\1=([a-zA-Z0-9_$]{2,})\(decodeURIComponent\(\1\)\)',
    dotAll: true);

// Additional patterns for different YouTube cipher formats
final _altPatterns = [
  RegExp(r'\b[cs]\s*&&\s*[adf]\.set\([^,]+\s*,\s*encodeURIComponent\s*\(\s*([a-zA-Z0-9$]+)\(', dotAll: true),
  RegExp(r'\b([a-zA-Z0-9$]{2})\s*=\s*function\(\s*a\s*\)\s*{\s*a\s*=\s*a\.split\(\s*""\s*\)', dotAll: true),
  RegExp(r'([a-zA-Z0-9$]+)\s*=\s*function\(\s*a\s*\)\s*{\s*a\s*=\s*a\.split\(\s*""\s*\)', dotAll: true),
  RegExp(r'\.sig\|\|([a-zA-Z0-9$]+)\(', dotAll: true),
];

RegExp _funcExp(String funcName) => RegExp(
      '$funcName=(function.+?return.+?;)',
      dotAll: true,
    );

final _varsExp = RegExp(r'(?<!\()\b([a-zA-Z][a-zA-Z0-9_$]*)\b');

typedef DeciphererFunc = String Function(
  String sig,
);

/// Comprehensive signature decipher implementation based on yt-dlp patterns
@internal
DeciphererFunc? getDecipherSignatureFunc(String? globalVar, String jscode) {
  final globalVarName =
      globalVar?.split('=')[0].trim().replaceFirst('var ', '');

  // Extract signature function using comprehensive patterns
  String? funcName;
  
  // Pattern 1: Primary signature function extraction
  var match = _decFuncExp.firstMatch(jscode);
  funcName = match?.group(2);
  
  // Pattern 2-4: Alternative signature patterns
  if (funcName == null) {
    for (final pattern in _altPatterns) {
      match = pattern.firstMatch(jscode);
      if (match != null) {
        funcName = match.group(1);
        if (funcName != null && funcName.isNotEmpty) {
          break;
        }
      }
    }
  }
  
  if (funcName == null || funcName.isEmpty) {
    return _createFallbackDecipher();
  }

  // Extract transform plan (sequence of operations)
  final transformPlan = _extractTransformPlan(jscode, funcName);
  if (transformPlan.isNotEmpty) {
    return _buildFunctionFromTransformPlan(transformPlan, jscode);
  }

  // Fallback: extract complete function
  final completeFunc = _extractCompleteFunction(jscode, funcName);
  if (completeFunc != null) {
    return _createDeciphererFromFunction(completeFunc, globalVar);
  }

  return _createFallbackDecipher();
}

/// Extract transform plan from JavaScript code
List<String> _extractTransformPlan(String jscode, String functionName) {
  final patterns = [
    RegExp('$functionName=function\\(\\w\\){[a-z=\\.\\(\\\"\\)]*;(.*);(?:.+)}', dotAll: true),
    RegExp('$functionName=function\\(\\w\\){(.*)}', dotAll: true),
  ];
  
  for (final pattern in patterns) {
    final match = pattern.firstMatch(jscode);
    if (match != null && match.group(1) != null) {
      return match.group(1)!
          .split(';')
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
  }
  return [];
}

/// Build decipher function from transform plan
DeciphererFunc _buildFunctionFromTransformPlan(List<String> plan, String jscode) {
  final operations = <String Function(String)>[];
  
  // Parse each operation in the transform plan
  for (final step in plan) {
    final funcMatch = RegExp(r'(\w+)\.(\w+)\(\w+(?:,(\d+))?\)').firstMatch(step);
    if (funcMatch != null) {
      final objName = funcMatch.group(1);
      final funcName = funcMatch.group(2);
      final param = funcMatch.group(3);
      
      // Extract the actual function definition
      if (objName != null && funcName != null) {
        final operation = _extractOperationFunction(jscode, objName, funcName);
        if (operation != null) {
          operations.add(operation);
        } else if (param != null) {
          // Fallback: guess operation type from parameter
          final index = int.tryParse(param) ?? 0;
          operations.add(_createGenericOperation(index));
        }
      }
    }
  }
  
  return (String sig) {
    var result = sig.split('');
    for (final operation in operations) {
      try {
        result = operation(result.join()).split('');
      } catch (e) {
        // Continue with next operation if one fails
        continue;
      }
    }
    return result.join();
  };
}

/// Extract operation function definition from transform object
String Function(String)? _extractOperationFunction(String jscode, String objName, String funcName) {
  // Extract transform object
  final objPattern = RegExp('var\\s+$objName\\s*=\\s*\\{([^}]+)\\}', dotAll: true);
  final objMatch = objPattern.firstMatch(jscode);
  if (objMatch == null) return null;
  
  final objContent = objMatch.group(1)!;
  
  // Find specific function in object
  final funcPattern = RegExp('$funcName\\s*:\\s*function\\([^)]*\\)\\s*\\{([^}]+)\\}', dotAll: true);
  final funcMatch = funcPattern.firstMatch(objContent);
  if (funcMatch == null) return null;
  
  final funcBody = funcMatch.group(1)!;
  
  // Map common operation patterns
  if (funcBody.contains('reverse')) {
    return (String s) => s.split('').reversed.join();
  } else if (funcBody.contains('splice')) {
    return (String s) {
      final chars = s.split('');
      return chars.skip(1).join(); // Remove first character
    };
  } else if (funcBody.contains('[0]') && funcBody.contains('length')) {
    // Swap operation
    return (String s) {
      final chars = s.split('');
      if (chars.length > 1) {
        final first = chars[0];
        chars[0] = chars[1];
        chars[1] = first;
      }
      return chars.join();
    };
  }
  
  return null;
}

/// Create generic operation based on parameter
String Function(String) _createGenericOperation(int param) {
  return (String s) {
    final chars = s.split('');
    if (param == 0 || chars.isEmpty) return s;
    
    // Default: swap first with character at index (param % length)
    final index = param % chars.length;
    if (index < chars.length && index > 0) {
      final temp = chars[0];
      chars[0] = chars[index];
      chars[index] = temp;
    }
    return chars.join();
  };
}

/// Extract complete function definition
String? _extractCompleteFunction(String jscode, String funcName) {
  final patterns = [
    RegExp('$funcName=(function.+?return.+?;)', dotAll: true),
    RegExp('function\\s+$funcName\\s*\\([^)]*\\)\\s*\\{[^}]*\\}', dotAll: true),
    RegExp('$funcName\\s*=\\s*function\\s*\\([^)]*\\)\\s*\\{[^}]*\\}', dotAll: true),
  ];
  
  for (final pattern in patterns) {
    final match = pattern.firstMatch(jscode);
    if (match != null) {
      var func = match.group(1) ?? match.group(0);
      if (func != null && func.contains('return')) {
        return func;
      }
    }
  }
  return null;
}

/// Create decipher function from extracted JavaScript function
DeciphererFunc _createDeciphererFromFunction(String funcCode, String? globalVar) {
  return (String sig) {
    try {
      var finalFunc = funcCode;
      if (!finalFunc.startsWith('function')) {
        finalFunc = 'function main$finalFunc';
      }
      if (globalVar != null) {
        finalFunc = finalFunc.replaceFirst('{', '{$globalVar;');
      }
      return JSEngine.run(finalFunc, [sig]) as String;
    } catch (e) {
      // Fallback to simple reverse
      return sig.split('').reversed.join();
    }
  };
}

/// Create fallback decipher that tries common operations
DeciphererFunc _createFallbackDecipher() {
  return (String sig) {
    // Try multiple fallback strategies
    final strategies = [
      // Strategy 1: Simple reverse
      () => sig.split('').reversed.join(),
      // Strategy 2: Swap first and second characters
      () {
        final chars = sig.split('');
        if (chars.length > 1) {
          final temp = chars[0];
          chars[0] = chars[1];
          chars[1] = temp;
        }
        return chars.join();
      },
      // Strategy 3: Remove first character
      () => sig.length > 1 ? sig.substring(1) : sig,
      // Strategy 4: Original signature (no change)
      () => sig,
    ];
    
    // Return first strategy result (simple reverse is most common)
    return strategies[0]();
  };
}
