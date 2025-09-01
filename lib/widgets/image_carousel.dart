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
      // Muestra un contenedor con un ícono si no hay fotos, en lugar de nada.
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Icon(
            Icons.camera_alt_outlined,
            color: Colors.grey[600],
            size: 50,
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        PageView.builder(
          itemCount: widget.fotos.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) {
            final imageUrl = widget.fotos[i];

            // --- MODIFICACIÓN: Lógica para manejar imágenes de assets o de red ---
            if (imageUrl.startsWith('assets/')) {
              // Si la ruta comienza con 'assets/', es una imagen local.
              return Image.asset(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
              );
            } else {
              // De lo contrario, es una imagen de internet.
              return CachedNetworkImage(
                imageUrl: imageUrl,
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
              );
            }
          },
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