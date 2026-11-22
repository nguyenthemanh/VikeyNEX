// Device-side runner for the 14 livetest cases. Same key mapping and edit contract as napi_init.cpp.
#include "Driver.h"
#include <cstdio>
#include <string>
#include <vector>

int vLanguage = 1;
int vSwitchKeyStatus = 0;
int vCheckSpelling = 1;
int vUseModernOrthography = 1;
int vRestoreIfWrongSpelling = 1;
int vFixRecommendBrowser = 1;
int vUseSmartSwitchKey = 0;
int vOtherLanguage = 0;
int vAutoSwitchByTyping = 1;

static bool keyFor(char16_t c, Uint16 &key, bool &shift) {
    static const Uint16 letters[26] = {
        KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F, KEY_G, KEY_H, KEY_I, KEY_J, KEY_K, KEY_L, KEY_M,
        KEY_N, KEY_O, KEY_P, KEY_Q, KEY_R, KEY_S, KEY_T, KEY_U, KEY_V, KEY_W, KEY_X, KEY_Y, KEY_Z};
    static const Uint16 digits[10] = {KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9};
    shift = false;
    if (c >= 'a' && c <= 'z') { key = letters[c - 'a']; return true; }
    if (c >= 'A' && c <= 'Z') { key = letters[c - 'A']; shift = true; return true; }
    if (c >= '0' && c <= '9') { key = digits[c - '0']; return true; }
    switch (c) {
        case ' ': key = KEY_SPACE; return true;
        case '\n': key = KEY_RETURN; return true;
        case ',': key = KEY_COMMA; return true;
        case '.': key = KEY_DOT; return true;
        case ';': key = KEY_SEMICOLON; return true;
        case ':': key = KEY_SEMICOLON; shift = true; return true;
        case '?': key = KEY_SLASH; shift = true; return true;
        case '/': key = KEY_SLASH; return true;
        case '!': key = KEY_1; shift = true; return true;
        case '\'': key = KEY_QUOTE; return true;
        case '"': key = KEY_QUOTE; shift = true; return true;
        case '(': key = KEY_9; shift = true; return true;
        case ')': key = KEY_0; shift = true; return true;
        case '-': key = KEY_MINUS; return true;
        default: return false;
    }
}

static std::u16string utf16(const std::string &utf8) {
    std::u16string out;
    for (size_t i = 0; i < utf8.size();) {
        unsigned char c = static_cast<unsigned char>(utf8[i]);
        char32_t cp = c;
        size_t n = 1;
        if ((c & 0x80) == 0) {
            n = 1;
        } else if ((c & 0xE0) == 0xC0 && i + 1 < utf8.size()) {
            cp = ((c & 0x1F) << 6) | (utf8[i + 1] & 0x3F);
            n = 2;
        } else if ((c & 0xF0) == 0xE0 && i + 2 < utf8.size()) {
            cp = ((c & 0x0F) << 12) | ((utf8[i + 1] & 0x3F) << 6) | (utf8[i + 2] & 0x3F);
            n = 3;
        } else if ((c & 0xF8) == 0xF0 && i + 3 < utf8.size()) {
            cp = ((c & 0x07) << 18) | ((utf8[i + 1] & 0x3F) << 12) | ((utf8[i + 2] & 0x3F) << 6) | (utf8[i + 3] & 0x3F);
            n = 4;
        }
        if (cp <= 0xFFFF) {
            out.push_back(static_cast<char16_t>(cp));
        } else {
            cp -= 0x10000;
            out.push_back(static_cast<char16_t>(0xD800 + (cp >> 10)));
            out.push_back(static_cast<char16_t>(0xDC00 + (cp & 0x3FF)));
        }
        i += n;
    }
    return out;
}

static std::string utf8(const std::u16string &in) {
    std::string out;
    for (char16_t cu : in) {
        char32_t cp = cu;
        if (cp < 0x80) {
            out.push_back(static_cast<char>(cp));
        } else if (cp < 0x800) {
            out.push_back(static_cast<char>(0xC0 | (cp >> 6)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        } else {
            out.push_back(static_cast<char>(0xE0 | (cp >> 12)));
            out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        }
    }
    return out;
}

static std::u16string applyEdit(std::u16string text, const VKEdit &edit) {
    int remove = edit.deleteCount;
    std::u16string add = edit.text;
    if (remove > 0 && static_cast<int>(text.size()) >= remove) {
        std::u16string old = text.substr(text.size() - static_cast<size_t>(remove));
        size_t same = 0;
        while (same < old.size() && same < add.size() && old[same] == add[same]) {
            same++;
        }
        remove -= static_cast<int>(same);
        add = add.substr(same);
    }
    if (remove > static_cast<int>(text.size())) {
        remove = static_cast<int>(text.size());
    }
    if (remove > 0) {
        text.erase(text.size() - static_cast<size_t>(remove));
    }
    text += add;
    return text;
}

static std::vector<std::u16string> split(const std::u16string &keys) {
    std::vector<std::u16string> out;
    std::u16string buf;
    const std::u16string back = utf16("\\b");
    const std::u16string alt = utf16("{alt+z}");
    for (size_t i = 0; i < keys.size();) {
        if (keys.compare(i, back.size(), back) == 0) {
            if (!buf.empty()) { out.push_back(buf); buf.clear(); }
            out.push_back(utf16("\b"));
            i += back.size();
        } else if (keys.compare(i, alt.size(), alt) == 0) {
            if (!buf.empty()) { out.push_back(buf); buf.clear(); }
            out.push_back(alt);
            i += alt.size();
        } else {
            buf.push_back(keys[i]);
            i++;
        }
    }
    if (!buf.empty()) {
        out.push_back(buf);
    }
    return out;
}

static std::string run(int lang, const char *keys) {
    VikeyDriver driver;
    driver.autoSwitch = true;
    driver.pauseAfterManual = 5;
    vCheckSpelling = 1;
    vSetCheckSpelling();
    vRestoreIfWrongSpelling = 1;
    vUseModernOrthography = 1;
    vTelexStyle = 0;
    driver.setLanguage(lang);
    std::u16string text;
    double now = 1000;
    const std::u16string alt = utf16("{alt+z}");
    for (const std::u16string &part : split(utf16(keys))) {
        now += 0.05;
        if (part == alt) {
            driver.manualSwitch(now);
            continue;
        }
        for (char16_t ch : part) {
            now += 0.02;
            if (ch == u'\b') {
                text = applyEdit(text, driver.press(KEY_DELETE, false, now));
                continue;
            }
            Uint16 key = 0;
            bool shift = false;
            if (!keyFor(ch, key, shift)) {
                driver.resetContext();
                VKEdit edit;
                edit.text.push_back(ch);
                text = applyEdit(text, edit);
                continue;
            }
            text = applyEdit(text, driver.press(key, shift, now));
        }
    }
    return utf8(text);
}

int main() {
    struct Spec { const char *name; int lang; const char *keys; const char *expected; };
    const Spec specs[] = {
        {"telex_basic", 1, "tieengs vieetj ", "tiếng việt "},
        {"telex_tone_anywhere", 1, "truowfng truongwf truwownfg ", "trường trường trường "},
        {"hoa_modern", 1, "hoaf ", "hoà "},
        {"restore_invalid", 1, "TestFlight ", "TestFlight "},
        {"auto_vi_to_en_more", 1, "more ", "more "},
        {"auto_en_word_mid_sentence", 1, "this makes sense ", "this makes sense "},
        {"auto_double_key_err", 1, "err ", "err "},
        {"auto_double_key_mix", 1, "mixx ", "mix "},
        {"auto_en_to_vi", 0, "truowfng ", "trường "},
        {"auto_en_stays_en", 0, "the theme of rust ", "the theme of rust "},
        {"auto_tie_vi_kept", 1, "tô thí ", "tô thí "},
        {"undo_backspace", 1, "more \\b", "moẻ"},
        {"identifier_guard", 0, "obj.dir my_var ", "obj.dir my_var "},
        {"hotkey_switch", 1, "{alt+z}tieng ", "tieng "},
    };
    int failed = 0;
    for (const Spec &spec : specs) {
        std::string got = run(spec.lang, spec.keys);
        bool ok = got == spec.expected;
        std::printf("%s %s\n  got: [%s]\n  exp: [%s]\n", ok ? "PASS" : "FAIL", spec.name, got.c_str(), spec.expected);
        if (!ok) {
            failed++;
        }
    }
    std::printf("%d failed\n", failed);
    return failed == 0 ? 0 : 1;
}
