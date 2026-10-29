import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../layout.dart';
import '../theme/yt_theme.dart';

/// A network image sized to its box (decoded at the box's pixel size), with YouTube's grey placeholder.
class YtImage extends StatelessWidget {
  const YtImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.radius = 0,
    this.circle = false,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final double? width;
  final double? height;
  final double radius;
  final bool circle;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(color: context.yt.skeleton);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final u = url;
    Widget image = u == null
        ? placeholder
        : CachedNetworkImage(
            imageUrl: u,
            fit: fit,
            memCacheWidth: width == null ? null : (width! * dpr).round(),
            fadeInDuration: const Duration(milliseconds: 120),
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          );
    if (circle) {
      image = ClipOval(child: image);
    } else if (radius > 0) {
      image = ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
    }
    return SizedBox(width: width, height: height, child: image);
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.url, {super.key, this.size = YtSizes.feedAvatar, this.name});

  final String? url;
  final double size;

  /// Shows the initial when there's no picture.
  final String? name;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: context.yt.chip,
        child: Text(
          (name ?? '?').replaceFirst('@', '').characters.firstOrNull?.toUpperCase() ?? '?',
          style: TextStyle(fontSize: size * 0.42, color: context.yt.textPrimary, fontWeight: FontWeight.w500),
        ),
      );
    }
    return YtImage(url, width: size, height: size, circle: true);
  }
}

/// The Videlon wordmark for the top bar: the mark plus "Videlon".
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.height = 22});

  final double height;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SvgPicture.asset('assets/branding/logo.svg', height: height * 1.45),
      const SizedBox(width: 4),
      Text(
        'Videlon',
        style: TextStyle(
          fontSize: height * 0.92,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: context.yt.textPrimary,
          height: 1,
        ),
      ),
    ],
  );
}

/// YouPipe's Shorts glyph: a phone-shaped rounded rectangle with a play triangle. It's our own mark, not YouTube's.
class ShortsIcon extends StatelessWidget {
  const ShortsIcon({super.key, this.size = 24, this.color, this.filled = false});

  final double size;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _ShortsPainter(color ?? IconTheme.of(context).color ?? context.yt.textPrimary, filled),
  );
}

class _ShortsPainter extends CustomPainter {
  _ShortsPainter(this.color, this.filled);

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(5.5 * s, 2.5 * s, 13 * s, 19 * s), Radius.circular(4 * s));
    final play = Path()
      ..moveTo(10 * s, 8.5 * s)
      ..lineTo(15.5 * s, 12 * s)
      ..lineTo(10 * s, 15.5 * s)
      ..close();
    if (filled) {
      canvas.drawPath(Path.combine(PathOperation.difference, Path()..addRRect(body), play), Paint()..color = color);
    } else {
      canvas.drawRRect(
        body,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * s,
      );
      canvas.drawPath(play, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_ShortsPainter old) => old.color != color || old.filled != filled;
}

/// A YouTube chip (Home topics, search filters, sort options).
class YtChip extends StatelessWidget {
  const YtChip({super.key, required this.label, this.selected = false, this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.yt;
    final fg = selected ? c.onChipSelected : c.textPrimary;
    return FocusHighlight(
      radius: YtSizes.chipRadius,
      child: Material(
        color: selected ? c.chipSelected : c.chip,
        borderRadius: BorderRadius.circular(YtSizes.chipRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(YtSizes.chipRadius),
          onTap: onTap,
          child: Container(
            height: YtSizes.chipHeight,
            padding: EdgeInsets.symmetric(horizontal: icon != null && label.isEmpty ? 8 : 12),
            // widthFactor 1: hug the label even under a bounded width (in a Wrap), instead of stretching.
            child: Align(
              widthFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) Icon(icon, size: 20, color: fg),
                  if (icon != null && label.isNotEmpty) const SizedBox(width: 6),
                  if (label.isNotEmpty) Text(label, style: YtText.chip.copyWith(color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontally scrolling row of chips.
class ChipBar extends StatelessWidget {
  const ChipBar({super.key, required this.children, this.padding = const EdgeInsets.symmetric(horizontal: 12)});

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: YtSizes.chipHeight + 16,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: padding.add(const EdgeInsets.symmetric(vertical: 8)),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) => children[i],
    ),
  );
}

/// The rounded pill buttons under a video (Share, Download, Save…).
class PillButton extends StatelessWidget {
  const PillButton({super.key, this.icon, this.label, this.onTap, this.filledIcon = false, this.child});

  final IconData? icon;
  final String? label;
  final VoidCallback? onTap;
  final bool filledIcon;

  /// Replaces the icon + label (e.g. the like/dislike pair).
  final Widget? child;

  @override
  Widget build(BuildContext context) => FocusHighlight(
    radius: 18,
    child: Material(
      color: context.yt.chip,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: YtSizes.pillHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child:
                child ??
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) Icon(icon, size: 20, fill: filledIcon ? 1 : 0),
                    if (icon != null && label != null) const SizedBox(width: 6),
                    if (label != null) Text(label!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
          ),
        ),
      ),
    ),
  );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(strokeWidth: 3, color: context.yt.textSecondary),
    ),
  );
}

/// Grey card shapes while a feed loads, like YouTube's skeletons.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.yt.skeleton;
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
    );
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ColoredBox(color: c),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(radius: 18, backgroundColor: c),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [bar(double.infinity, 14), const SizedBox(height: 8), bar(160, 12)],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A friendly error with a retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required
