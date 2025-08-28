import 'package:flutter/material.dart';

/// A widget that displays caching progress with percentage and optional logs
class CachingProgressWidget extends StatelessWidget {
  const CachingProgressWidget({
    super.key,
    required this.progress,
    this.showLogs = false,
    this.logs = const [],
    this.progressColor = Colors.blue,
    this.backgroundColor = Colors.grey,
    this.textColor = Colors.white,
    this.height = 4.0,
    this.borderRadius = 2.0,
    this.showPercentage = true,
    this.percentageTextStyle,
  });

  final double progress; // 0.0 to 1.0
  final bool showLogs;
  final List<String> logs;
  final Color progressColor;
  final Color backgroundColor;
  final Color textColor;
  final double height;
  final double borderRadius;
  final bool showPercentage;
  final TextStyle? percentageTextStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress bar with better visibility
        Container(
          height: height,
          decoration: BoxDecoration(
            color: backgroundColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: progressColor.withOpacity(0.3),
              width: 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ),

        // Percentage text
        if (showPercentage) ...[
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toInt()}%',
            style: percentageTextStyle ??
                TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: const [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
          ),
        ],

        // Logs (only if explicitly enabled)
        if (showLogs && logs.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 60),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: logs.length,
              itemBuilder: (context, index) {
                return Text(
                  logs[index],
                  style: TextStyle(
                    color: textColor.withOpacity(0.8),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// A model class for caching progress data
class CachingProgressData {
  const CachingProgressData({
    required this.progress,
    this.logs = const [],
    this.isVisible = true,
  });

  final double progress;
  final List<String> logs;
  final bool isVisible;

  CachingProgressData copyWith({
    double? progress,
    List<String>? logs,
    bool? isVisible,
  }) {
    return CachingProgressData(
      progress: progress ?? this.progress,
      logs: logs ?? this.logs,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}