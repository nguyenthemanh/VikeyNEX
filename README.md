# Vikey for HarmonyOS NEXT

## Giới thiệu

Vikey là bàn phím gõ tiếng Việt kiểu Telex và tiếng Anh cho HarmonyOS NEXT 6.0 (API 20) trở lên. Bản này sửa từ Vikey 1.0.32 của Tony Dinh, dựa trên OpenKey của Tuyen Mai. Engine gõ nằm trong `Engine/`, được biên dịch thành `libvikey.so` và gọi từ bộ gõ qua NAPI. Bàn phím là `InputMethodExtensionAbility` (`type: inputMethod`) dùng IME Kit, không kết nối mạng.

## Introduction

Vietnamese Telex and English keyboard for HarmonyOS NEXT 6.0 (API 20) and later. Modified from Vikey 1.0.32 by Tony Dinh, which is based on OpenKey by Tuyen Mai. The typing engine in `Engine/` is compiled into `libvikey.so` and called from the input method through NAPI. The keyboard is an `InputMethodExtensionAbility` (`type: inputMethod`) using IME Kit. It does not use the network.

## 简介

适用于 HarmonyOS NEXT 6.0（API 20）及更高版本的越南语 Telex 与英语键盘。本项目改自 Tony Dinh 的 Vikey 1.0.32，而 Vikey 基于 Tuyen Mai 的 OpenKey。输入引擎位于 `Engine/`，编译为 `libvikey.so`，由输入法通过 NAPI 调用。键盘是使用 IME Kit 的 `InputMethodExtensionAbility`（`type: inputMethod`），不访问网络。

## 紹介

HarmonyOS NEXT 6.0（API 20）以降向けの、ベトナム語 Telex と英語のキーボードです。Tony Dinh の Vikey 1.0.32（Tuyen Mai の OpenKey が基）を改変しています。入力エンジンは `Engine/` にあり、`libvikey.so` にコンパイルされ、NAPI 経由で入力メソッドから呼ばれます。キーボードは IME Kit の `InputMethodExtensionAbility`（`type: inputMethod`）で、ネットワークは使いません。

## Build

Open this folder in DevEco Studio 26, or from a shell with the DevEco SDK:

```
hvigorw assembleHap
```

`compatibleSdkVersion` is `6.0.0(20)`. `targetSdkVersion` is `26.0.0`. Devices: phone, tablet, 2-in-1.

## Use

Install the HAP, open Vikey, then turn the keyboard on in Settings, System, Keyboard and input method. Choose Vikey with the keyboard switcher. The system does not let an app enable an input method by itself.

## License

GNU GPL-3.0. See `LICENSE` and `NOTICE.md`. There is no warranty.
