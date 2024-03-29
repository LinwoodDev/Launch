import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';
import 'package:html/parser.dart' show parse;
import 'package:url_launcher/url_launcher_string.dart';

typedef SystemCallback = void Function();

abstract class AppEntry {
  final String name;
  final String description;
  void onTap();
  Widget? buildWidget(BuildContext context);

  AppEntry(this.name, {this.description = ''});
  AppEntry.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        description = json['description'] as String;

  Map<String, dynamic> toJson() => {'name': name, 'description': description};
}

class UrlEntry extends AppEntry {
  final String url;
  final String icon;

  UrlEntry(super.name, {super.description, required this.url, this.icon = ''});
  UrlEntry.fromJson(super.json)
      : url = json['url'] as String,
        icon = json['icon'] as String? ?? '',
        super.fromJson();

  static Future<UrlEntry> create(Uri uri) async {
    var icon = '';
    var name = uri.toString();
    var description = '';
    try {
      var response = await http
          .read(Uri(host: uri.host, port: uri.port, scheme: uri.scheme));
      var html = parse(response);
      var headElement = html.getElementsByTagName('head').firstOrNull;
      if (headElement != null) {
        description = headElement
                .getElementsByTagName('meta')
                .firstWhereOrNull(
                    (element) => element.attributes['name'] == 'description')
                ?.attributes['content'] ??
            description;
        int getSize(dom.Element e) =>
            int.tryParse(
                (e.attributes['sizes'] ?? '0x0').split('x').firstOrNull ??
                    '0') ??
            0;
        var icons = <dom.Element>[];
        icons.addAll(html
            .querySelectorAll('link')
            .where((element) =>
                element.attributes['rel']?.contains('icon') ?? false)
            .where((element) =>
                !(element.attributes['href']?.endsWith('.svg') ?? true))
            .toList()
          ..sort((a, b) =>
              (getSize(a) - 64).abs().compareTo((getSize(b) - 64).abs())));
        var iconTag = icons.firstOrNull;
        if (iconTag != null) {
          var iconUrl = (iconTag.attributes['href'] ?? '').trim();

          // Fix scheme relative URLs
          if (iconUrl.startsWith('//')) {
            iconUrl = '${uri.scheme}:$iconUrl';
          }

          // Fix relative URLs
          if (iconUrl.startsWith('/')) {
            iconUrl = '${uri.scheme}://${uri.host}$iconUrl';
          }

          // Fix naked URLs
          if (!iconUrl.startsWith('http')) {
            iconUrl = '${uri.scheme}://${uri.host}/$iconUrl';
          }

          // Remove query strings
          iconUrl = iconUrl.split('?').first;
          icon = iconUrl;
        }
      }
      name =
          headElement?.getElementsByTagName('title').firstOrNull?.innerHtml ??
              name;
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
    }
    if (icon.isEmpty) {
      try {
        var imageUri = Uri(
            host: uri.host,
            port: uri.port,
            scheme: uri.scheme,
            pathSegments: ['favicon.ico']);
        var response = await http.get(imageUri);
        if (response.statusCode == 200) icon = imageUri.toString();
      } catch (e) {
        if (kDebugMode) {
          print('Error: $e');
        }
      }
    }
    if (icon.isEmpty) {
      try {
        var imageUri = Uri(
            host: uri.host,
            port: uri.port,
            scheme: uri.scheme,
            pathSegments: ['favicon.png']);
        var response = await http.get(imageUri);
        if (response.statusCode == 200) icon = imageUri.toString();
      } catch (e) {
        if (kDebugMode) {
          print('Error: $e');
        }
      }
    }
    if (name.isEmpty) {
      name = '${uri.host[0]}${uri.host.substring(1)}';
    }

    return UrlEntry(name,
        url: uri.toString(), description: description, icon: icon);
  }

  @override
  Widget? buildWidget(BuildContext context) {
    return icon.isNotEmpty
        ? Image.network(icon, height: 42)
        : const Icon(PhosphorIcons.globeLight);
  }

  @override
  void onTap() => launchUrlString(url);

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..addAll({
      'type': 'url-entry',
      'url': url,
      'name': name,
      'description': description,
      'icon': icon
    });

  UrlEntry copyWith(
          {String? name, String? description, String? url, String? icon}) =>
      UrlEntry(name ?? this.name,
          url: url ?? this.url,
          description: description ?? this.description,
          icon: icon ?? this.icon);
}

class CommandEntry extends AppEntry {
  final String command;
  CommandEntry(super.name, {super.description, required this.command});
  @override
  void onTap() {
    if (kDebugMode) {
      print(command);
    }
  }

  @override
  Widget? buildWidget(BuildContext context) =>
      const Icon(PhosphorIcons.terminalLight);

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'command-entry', 'command': command};
}

class SystemEntry extends AppEntry {
  final SystemCallback onClick;
  final Widget? widget;
  SystemEntry(super.name,
      {super.description, required this.onClick, this.widget});

  @override
  Widget? buildWidget(BuildContext context) => widget;

  @override
  void onTap() => onClick();

  @override
  Map<String, dynamic> toJson() =>
      super.toJson()..addAll({'type': 'system-entry'});
}
