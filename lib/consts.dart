import 'package:flutter/material.dart';

const String googleAPiKeys = "AIzaSyBmaQap8imER9nVq_na_r54mTjRqoYS5Kk";

const double defaultHight = 15.0;

showError(BuildContext context, String message) async{
  if (message.isEmpty) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

const initialZoom = 15.0;
const animationDuration = Duration(milliseconds: 500);
const polylineWidth = 3.0;
const polylineColor = Colors.red;
