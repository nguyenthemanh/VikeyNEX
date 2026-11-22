# Vikey for HarmonyOS NEXT

## Giới thiệu

Vikey là bàn phím gõ tiếng Việt kiểu Telex và tiếng Anh cho HarmonyOS NEXT 6.0 (API 20) trở lên. Bản này sửa từ Vikey 1.0.32 của Tony Dinh, dựa trên OpenKey của Tuyen Mai. Engine gõ nằm trong `Engine/`, được biên dịch thành `libvikey.so` và gọi từ bộ gõ qua NAPI. Bàn phím là `InputMethodExtensionAbility` (`type: inputMethod`) dùng IME Kit, không kết nối mạng.

## Introduction

Vietnamese Telex and English keyboard for HarmonyOS NEXT 6.0 (API 20) and later. Modified from Vikey 1.0.32 by Tony Dinh, which is based on OpenKey by Tuyen Mai. The typing engine in `Engine/` is compiled into `libvikey.so` and called from the input method through NAPI. The keyboard is an `InputMethodExtensionAbility` (`type: inputMethod`) using IME Kit. It does not use the network.

## 简介

适用于 HarmonyOS NEXT 6.0（API 20）及更高版本的越南语 Telex 与英语键盘。本项目改自 Tony Dinh 的 Vikey 1.0.32，而 Vikey 基于 Tuyen Mai 的 OpenKey。输入引擎位于 `Engine/`，编译为 `libvikey.so`，由输入法通过 NAPI 调用。键盘是使用 IME Kit 的 `InputMethodExtensionAbility`（`type: inputMethod`），不访问网络。

## 紹介

HarmonyOS NEXT 6.0（API 20）以降向けの、ベトナム語 Telex と英語のキーボードです。Tony Dinh の Vikey 1.0.32（Tuyen Mai の OpenKey が基）を改変しています。入力エンジンは `Engine/` にあり、`libvikey.so` にコンパイルされ、NAPI 経由で入力メソッドから呼ばれます。キーボードは IME Kit の `InputMethodExtensionAbility`（`type: inputMethod`）で、ネットワークは使いません。

## Cài bản đã build

Tải file cài [release/Vikey-1.0.hap](https://github.com/nguyenthemanh/VikeyNEX/raw/main/release/Vikey-1.0.hap). Máy cần HarmonyOS NEXT 6.0 trở lên (điện thoại, máy tính bảng hoặc 2-in-1).

1. Bật tùy chọn nhà phát triển.
2. Chép file `.hap` vào máy và mở nó, hoặc cắm máy rồi chạy `hdc install -r Vikey-1.0.hap`.
3. Mở Vikey, vào Cài đặt, Hệ thống, Bàn phím và phương thức nhập, rồi bật Vikey. Hệ thống không cho ứng dụng tự bật bộ gõ.

Bản này được ký bằng chứng chỉ gỡ lỗi. Nếu máy báo thiết bị chưa được phép, hồ sơ ký không chứa máy đó. Khi ấy hãy tự build bằng chứng chỉ của bạn.

## Install the built package

Download the installer [release/Vikey-1.0.hap](https://github.com/nguyenthemanh/VikeyNEX/raw/main/release/Vikey-1.0.hap). The device must be HarmonyOS NEXT 6.0 or later (phone, tablet, or 2-in-1).

1. Turn on developer options.
2. Copy the `.hap` onto the device and open it, or connect the device and run `hdc install -r Vikey-1.0.hap`.
3. Open Vikey, then enable it in Settings, System, Keyboard and input method. The system does not let an app enable an input method by itself.

This package is signed with a debug certificate. If the device says it is not authorized, that device is not in the signing profile. Build the project with your own certificate in that case.

## 安装已构建的包

下载安装包 [release/Vikey-1.0.hap](https://github.com/nguyenthemanh/VikeyNEX/raw/main/release/Vikey-1.0.hap)。设备需为 HarmonyOS NEXT 6.0 或更高版本（手机、平板或二合一设备）。

1. 打开开发者选项。
2. 把 `.hap` 拷到设备上并打开，或连接设备后执行 `hdc install -r Vikey-1.0.hap`。
3. 打开 Vikey，在「设置 > 系统 > 键盘和输入法」中启用。系统不允许应用自行启用输入法。

此包使用调试证书签名。如果设备提示未授权，说明该设备不在签名描述文件中，请用你自己的证书重新构建。

## ビルド済みパッケージのインストール

インストール用ファイル [release/Vikey-1.0.hap](https://github.com/nguyenthemanh/VikeyNEX/raw/main/release/Vikey-1.0.hap) をダウンロードします。HarmonyOS NEXT 6.0 以降のスマホ、タブレット、または 2-in-1 が必要です。

1. 開発者オプションをオンにします。
2. `.hap` を端末にコピーして開くか、端末を接続して `hdc install -r Vikey-1.0.hap` を実行します。
3. Vikey を開き、「設定 > システム > キーボードと入力」で有効にします。システムはアプリ自身に入力メソッドを有効にさせません。

このパッケージはデバッグ証明書で署名されています。端末が未許可と表示する場合、その端末は署名プロファイルに含まれていません。そのときは自分の証明書でビルドしてください。

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
