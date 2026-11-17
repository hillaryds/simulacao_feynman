import 'package:flutter/material.dart';

enum ParticleSpecies { light, heavy }

class GasParticle {
  Offset position;
  Offset velocity;
  final ParticleSpecies species;
  final double radius;
  final double mass;

  GasParticle({
    required this.position,
    required this.velocity,
    required this.species,
    required this.radius,
    required this.mass,
  });
}
