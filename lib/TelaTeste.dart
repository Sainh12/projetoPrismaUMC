import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main () {
  runApp(const TelaTeste());
}

class User {
  final String id;
  final String nome;
  final String email;
  final String escola;
  final String serie;
  final String turma;
  User({required this.id,required this.nome, required this.email, required this.escola, required this.serie, required this.turma})

  factory User.fromJson(Map<String,dynamic> json){
    return User(
      id: json['id'],
      nome:json['nome'],
      email: json['email'],
      escola: json['escola'],
      serie: json['serie'],
      turma: json['turma'],
    );
  } 
}