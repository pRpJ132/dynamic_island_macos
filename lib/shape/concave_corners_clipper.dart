import 'dart:ui';

import 'package:flutter/material.dart';

class ConcaveCornersClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const double r = 12;
    const double rb = 12;
    Path path = Path();

    path.moveTo(0, 0);
    path.quadraticBezierTo(r, 0, r, r);

    path.lineTo(r, size.height - rb);
    path.arcToPoint(
      Offset(r + rb, size.height),
      radius: Radius.circular(rb),
      clockwise: false,
    );

    path.lineTo(size.width - r - rb, size.height);
    path.arcToPoint(
      Offset(size.width - r, size.height - rb),
      radius: Radius.circular(rb),
      clockwise: false,
    );

    path.lineTo(size.width - r, r);
    path.quadraticBezierTo(size.width - r, 0, size.width, 0);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}