import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageCarousel extends StatefulWidget {
  final List<String> fotos;

  const ImageCarousel({super.key, required this.fotos});

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.fotos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        PageView.builder(
          itemCount: widget.fotos.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => CachedNetworkImage(
            imageUrl: widget.fotos[i],
            fit: BoxFit.cover,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF920606),
              ),
            ),
            errorWidget: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image, size: 40),
            ),
          ),
        ),
        if (widget.fotos.length > 1)
          Positioned(
            bottom: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.fotos.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _current == i ? 12 : 8,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _current == i
                        ? const Color(0xFF920606)
                        : Colors.white.withAlpha(178),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
