import 'package:http/http.dart' as original_http;
export 'package:http/http.dart' show MultipartFile, Response;
import 'dart:convert';
import 'sesi_user.dart';

Map<String, String> _addHeaders(Map<String, String>? headers) {
  final h = headers ?? {};
  h['Accept'] = 'application/json';
  h['ngrok-skip-browser-warning'] = 'true';
  if (SesiUser.token != null) {
    h['Authorization'] = 'Bearer ${SesiUser.token}';
  }
  return h;
}

Future<original_http.Response> get(Uri url, {Map<String, String>? headers}) {
  return original_http.get(url, headers: _addHeaders(headers));
}

Future<original_http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
  return original_http.post(url, headers: _addHeaders(headers), body: body, encoding: encoding);
}

Future<original_http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
  return original_http.put(url, headers: _addHeaders(headers), body: body, encoding: encoding);
}

Future<original_http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
  return original_http.delete(url, headers: _addHeaders(headers), body: body, encoding: encoding);
}

class MultipartRequest extends original_http.MultipartRequest {
  MultipartRequest(String method, Uri url) : super(method, url) {
    headers.addAll(_addHeaders(null));
  }
}
