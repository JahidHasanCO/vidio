import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vidio/src/source/video_style.dart';

/// Action bar widget that displays controls at the top of the video player
class ActionBar extends StatelessWidget {
  const ActionBar({
    required this.showMenu,
    required this.fullScreen,
    required this.isLocked,
    required this.videoStyle,
    required this.onSupportButtonTap,
    required this.onLockTap,
    required this.onVideoListTap,
    required this.onSettingsTap,
    super.key,
  });

  final bool showMenu;
  final bool fullScreen;
  final bool isLocked;
  final VideoStyle videoStyle;
  final VoidCallback? onSupportButtonTap;
  final VoidCallback onLockTap;
  final VoidCallback? onVideoListTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: showMenu,
      child: Align(
        alignment: Alignment.topCenter,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            width: MediaQuery.of(context).size.width,
            padding: videoStyle.actionBarPadding ?? EdgeInsets.zero,
            alignment: Alignment.topRight,
            color: videoStyle.actionBarBgColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (fullScreen) ...[
                  if (onSupportButtonTap != null)
                    InkWell(
                      onTap: onSupportButtonTap,
                      child: Container(
                        height: 50,
                        width: 50,
                        margin: fullScreen ? const EdgeInsets.only(top: 10) : null,
                        child: const Icon(
                          Icons.support_agent,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  InkWell(
                    onTap: onLockTap,
                    child: Container(
                      height: 50,
                      width: 50,
                      margin: fullScreen ? const EdgeInsets.only(top: 10) : null,
                      child: Icon(
                        isLocked ? Icons.lock : Icons.lock_open_sharp,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  if (onVideoListTap != null)
                    InkWell(
                      onTap: onVideoListTap,
                      child: Container(
                        height: 50,
                        width: 50,
                        margin: fullScreen ? const EdgeInsets.only(top: 10) : null,
                        child: SvgPicture.asset(
                          'packages/vidio/assets/icons/playlist.svg',
                          width: 24,
                          height: 24,
                          fit: BoxFit.scaleDown,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                ],
                InkWell(
                  onTap: onSettingsTap,
                  child: Container(
                    height: 50,
                    width: 50,
                    margin: fullScreen ? const EdgeInsets.only(top: 10) : null,
                    child: const Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                SizedBox(
                  width: videoStyle.qualityButtonAndFullScrIcoSpace,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}