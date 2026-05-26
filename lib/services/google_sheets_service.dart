import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';

class GoogleSheetsService {
  static const String spreadsheetId = '1lkImcQTYrsKBc4eafO6AOyRqlqhXTXnn40gYb4B5jzM';

  static Future<sheets.SheetsApi> _getSheetsApi() async {
    final credentialsJson = await rootBundle.loadString('assets/google-sheets-credentials.json');
    final credentials = ServiceAccountCredentials.fromJson(jsonDecode(credentialsJson));
    final scopes = [sheets.SheetsApi.spreadsheetsScope];
    final client = await clientViaServiceAccount(credentials, scopes);
    return sheets.SheetsApi(client);
  }

  // Returns null on success, error message on failure
  static Future<String?> editRow({
    required String ivNo,
    required Map<String, String> updates,
  }) async {
    try {
      final sheetsApi = await _getSheetsApi();
      
      // 1. Fetch the data range to find the row index
      final response = await sheetsApi.spreadsheets.values.get(spreadsheetId, 'Sheet1!A:Z');
      final rows = response.values;
      if (rows == null || rows.isEmpty) {
        return 'The sheet is empty or could not be loaded.';
      }

      // 2. Find the header row (first cell is 'Date', case-insensitive)
      int headerRowIndex = -1;
      for (int i = 0; i < rows.length; i++) {
        if (rows[i].isNotEmpty && rows[i][0].toString().toLowerCase() == 'date') {
          headerRowIndex = i;
          break;
        }
      }

      if (headerRowIndex == -1) {
        return 'Header row not found (cell A must be "Date").';
      }

      final headers = rows[headerRowIndex].map((h) => h.toString().toLowerCase().trim()).toList();
      
      // Find IV NO column index
      final ivNoColIndex = headers.indexOf('iv no');
      if (ivNoColIndex == -1) {
        return 'Column "IV NO" not found in sheet headers.';
      }

      // 3. Find the target row matching the ivNo
      int targetRowIndex = -1;
      for (int i = headerRowIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length > ivNoColIndex && row[ivNoColIndex].toString().trim().toLowerCase() == ivNo.trim().toLowerCase()) {
          targetRowIndex = i;
          break;
        }
      }

      if (targetRowIndex == -1) {
        return 'Row with IV NO "$ivNo" not found in the sheet.';
      }

      // The 1-based index in the sheet (row index + 1)
      final sheetRowNumber = targetRowIndex + 1;

      // 4. Update the columns
      for (final col in updates.keys) {
        final colIndex = headers.indexOf(col.toLowerCase().trim());
        if (colIndex != -1) {
          final colLetter = _getColLetter(colIndex);
          final valueRange = sheets.ValueRange(
            values: [[updates[col]]],
          );
          
          await sheetsApi.spreadsheets.values.update(
            valueRange,
            spreadsheetId,
            'Sheet1!$colLetter$sheetRowNumber',
            valueInputOption: 'USER_ENTERED',
          );
        }
      }
      return null;
    } catch (e) {
      return 'Google Sheets API error: $e';
    }
  }

  // Returns null on success, error message on failure
  static Future<String?> deleteRow({
    required String ivNo,
  }) async {
    try {
      final sheetsApi = await _getSheetsApi();
      
      // 1. Fetch the data range to find the row index
      final response = await sheetsApi.spreadsheets.values.get(spreadsheetId, 'Sheet1!A:Z');
      final rows = response.values;
      if (rows == null || rows.isEmpty) {
        return 'The sheet is empty or could not be loaded.';
      }

      // 2. Find the header row (first cell is 'Date', case-insensitive)
      int headerRowIndex = -1;
      for (int i = 0; i < rows.length; i++) {
        if (rows[i].isNotEmpty && rows[i][0].toString().toLowerCase() == 'date') {
          headerRowIndex = i;
          break;
        }
      }

      if (headerRowIndex == -1) {
        return 'Header row not found (cell A must be "Date").';
      }

      final headers = rows[headerRowIndex].map((h) => h.toString().toLowerCase().trim()).toList();
      
      // Find IV NO column index
      final ivNoColIndex = headers.indexOf('iv no');
      if (ivNoColIndex == -1) {
        return 'Column "IV NO" not found in sheet headers.';
      }

      // 3. Find the target row matching the ivNo
      int targetRowIndex = -1;
      for (int i = headerRowIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length > ivNoColIndex && row[ivNoColIndex].toString().trim().toLowerCase() == ivNo.trim().toLowerCase()) {
          targetRowIndex = i;
          break;
        }
      }

      if (targetRowIndex == -1) {
        return 'Row with IV NO "$ivNo" not found in the sheet.';
      }

      // The 1-based index in the sheet (row index + 1)
      final sheetRowNumber = targetRowIndex + 1;

      // 4. Send the batchUpdate delete request
      final request = sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(
            deleteDimension: sheets.DeleteDimensionRequest(
              range: sheets.DimensionRange(
                sheetId: 0, // Sheet1 is gid=0
                dimension: 'ROWS',
                startIndex: sheetRowNumber - 1, // 0-indexed inclusive
                endIndex: sheetRowNumber,       // 0-indexed exclusive
              ),
            ),
          ),
        ],
      );
      
      await sheetsApi.spreadsheets.batchUpdate(request, spreadsheetId);
      return null;
    } catch (e) {
      return 'Google Sheets API error: $e';
    }
  }

  static String _getColLetter(int colIndex) {
    String letter = '';
    while (colIndex >= 0) {
      letter = String.fromCharCode((colIndex % 26) + 65) + letter;
      colIndex = (colIndex ~/ 26) - 1;
    }
    return letter;
  }
}
