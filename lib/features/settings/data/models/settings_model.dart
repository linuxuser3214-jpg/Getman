import 'package:getman/core/theme/theme_ids.dart';
import 'package:getman/features/settings/domain/entities/settings_entity.dart';
import 'package:hive/hive.dart';

part 'settings_model.g.dart';

const Object _unchanged = Object();

@HiveType(typeId: 0)
class SettingsModel extends HiveObject {
  @HiveField(0, defaultValue: 100)
  int historyLimit;

  @HiveField(1, defaultValue: false)
  bool saveResponseInHistory;

  @HiveField(2, defaultValue: false)
  bool isDarkMode;

  @HiveField(3, defaultValue: false)
  bool isCompactMode;

  @HiveField(4, defaultValue: false)
  bool isVerticalLayout;

  @HiveField(5, defaultValue: 0.5)
  double splitRatio;

  @HiveField(6, defaultValue: 300.0)
  double sideMenuWidth;

  @HiveField(7, defaultValue: kBrutalistThemeId)
  String themeId;

  @HiveField(8)
  String? activeEnvironmentId;

  @HiveField(9, defaultValue: 30000)
  int connectTimeoutMs;

  @HiveField(10, defaultValue: 30000)
  int sendTimeoutMs;

  @HiveField(11, defaultValue: 60000)
  int receiveTimeoutMs;

  @HiveField(12, defaultValue: true)
  bool followRedirects;

  @HiveField(13, defaultValue: true)
  bool verifySsl;

  @HiveField(14)
  String? proxyUrl;

  @HiveField(15)
  String? workspacePath;

  SettingsModel({
    this.historyLimit = 100,
    this.saveResponseInHistory = false,
    this.isDarkMode = false,
    this.isCompactMode = false,
    this.isVerticalLayout = false,
    this.splitRatio = 0.5,
    this.sideMenuWidth = 300.0,
    this.themeId = kBrutalistThemeId,
    this.activeEnvironmentId,
    this.connectTimeoutMs = 30000,
    this.sendTimeoutMs = 30000,
    this.receiveTimeoutMs = 60000,
    this.followRedirects = true,
    this.verifySsl = true,
    this.proxyUrl,
    this.workspacePath,
  });

  SettingsModel copyWith({
    int? historyLimit,
    bool? saveResponseInHistory,
    bool? isDarkMode,
    bool? isCompactMode,
    bool? isVerticalLayout,
    double? splitRatio,
    double? sideMenuWidth,
    String? themeId,
    Object? activeEnvironmentId = _unchanged,
    int? connectTimeoutMs,
    int? sendTimeoutMs,
    int? receiveTimeoutMs,
    bool? followRedirects,
    bool? verifySsl,
    Object? proxyUrl = _unchanged,
    Object? workspacePath = _unchanged,
  }) {
    return SettingsModel(
      historyLimit: historyLimit ?? this.historyLimit,
      saveResponseInHistory: saveResponseInHistory ?? this.saveResponseInHistory,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isCompactMode: isCompactMode ?? this.isCompactMode,
      isVerticalLayout: isVerticalLayout ?? this.isVerticalLayout,
      splitRatio: splitRatio ?? this.splitRatio,
      sideMenuWidth: sideMenuWidth ?? this.sideMenuWidth,
      themeId: themeId ?? this.themeId,
      activeEnvironmentId: identical(activeEnvironmentId, _unchanged)
          ? this.activeEnvironmentId
          : activeEnvironmentId as String?,
      connectTimeoutMs: connectTimeoutMs ?? this.connectTimeoutMs,
      sendTimeoutMs: sendTimeoutMs ?? this.sendTimeoutMs,
      receiveTimeoutMs: receiveTimeoutMs ?? this.receiveTimeoutMs,
      followRedirects: followRedirects ?? this.followRedirects,
      verifySsl: verifySsl ?? this.verifySsl,
      proxyUrl: identical(proxyUrl, _unchanged) ? this.proxyUrl : proxyUrl as String?,
      workspacePath:
          identical(workspacePath, _unchanged) ? this.workspacePath : workspacePath as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'historyLimit': historyLimit,
    'saveResponseInHistory': saveResponseInHistory,
    'isDarkMode': isDarkMode,
    'isCompactMode': isCompactMode,
    'isVerticalLayout': isVerticalLayout,
    'splitRatio': splitRatio,
    'sideMenuWidth': sideMenuWidth,
    'themeId': themeId,
    'activeEnvironmentId': activeEnvironmentId,
    'connectTimeoutMs': connectTimeoutMs,
    'sendTimeoutMs': sendTimeoutMs,
    'receiveTimeoutMs': receiveTimeoutMs,
    'followRedirects': followRedirects,
    'verifySsl': verifySsl,
    'proxyUrl': proxyUrl,
    'workspacePath': workspacePath,
  };

  factory SettingsModel.fromJson(Map<String, dynamic> json) => SettingsModel(
    historyLimit: json['historyLimit'] ?? 100,
    saveResponseInHistory: json['saveResponseInHistory'] ?? false,
    isDarkMode: json['isDarkMode'] ?? false,
    isCompactMode: json['isCompactMode'] ?? false,
    isVerticalLayout: json['isVerticalLayout'] ?? false,
    splitRatio: json['splitRatio'] ?? 0.5,
    sideMenuWidth: (json['sideMenuWidth'] ?? 300.0).toDouble(),
    themeId: json['themeId'] ?? kBrutalistThemeId,
    activeEnvironmentId: json['activeEnvironmentId'] as String?,
    connectTimeoutMs: json['connectTimeoutMs'] ?? 30000,
    sendTimeoutMs: json['sendTimeoutMs'] ?? 30000,
    receiveTimeoutMs: json['receiveTimeoutMs'] ?? 60000,
    followRedirects: json['followRedirects'] ?? true,
    verifySsl: json['verifySsl'] ?? true,
    proxyUrl: json['proxyUrl'] as String?,
    workspacePath: json['workspacePath'] as String?,
  );

  factory SettingsModel.fromEntity(SettingsEntity entity) => SettingsModel(
    historyLimit: entity.historyLimit,
    saveResponseInHistory: entity.saveResponseInHistory,
    isDarkMode: entity.isDarkMode,
    isCompactMode: entity.isCompactMode,
    isVerticalLayout: entity.isVerticalLayout,
    splitRatio: entity.splitRatio,
    sideMenuWidth: entity.sideMenuWidth,
    themeId: entity.themeId,
    activeEnvironmentId: entity.activeEnvironmentId,
    connectTimeoutMs: entity.connectTimeoutMs,
    sendTimeoutMs: entity.sendTimeoutMs,
    receiveTimeoutMs: entity.receiveTimeoutMs,
    followRedirects: entity.followRedirects,
    verifySsl: entity.verifySsl,
    proxyUrl: entity.proxyUrl,
    workspacePath: entity.workspacePath,
  );

  SettingsEntity toEntity() => SettingsEntity(
    historyLimit: historyLimit,
    saveResponseInHistory: saveResponseInHistory,
    isDarkMode: isDarkMode,
    isCompactMode: isCompactMode,
    isVerticalLayout: isVerticalLayout,
    splitRatio: splitRatio,
    sideMenuWidth: sideMenuWidth,
    themeId: themeId,
    activeEnvironmentId: activeEnvironmentId,
    connectTimeoutMs: connectTimeoutMs,
    sendTimeoutMs: sendTimeoutMs,
    receiveTimeoutMs: receiveTimeoutMs,
    followRedirects: followRedirects,
    verifySsl: verifySsl,
    proxyUrl: proxyUrl,
    workspacePath: workspacePath,
  );
}
