// NAPI face of Engine/Driver + TouchModel. Modified 2026-11-09 for HarmonyOS NEXT.
// The packed-string contract matches Android/app/src/main/cpp/vikey_jni.cpp.
#include "napi/native_api.h"
#include <string>
#include <vector>
#include <cstring>
#include <cstdlib>
#include <memory>
#include "Driver.h"
#include "TouchModel.h"

int vLanguage = 1;
int vSwitchKeyStatus = 0;
int vCheckSpelling = 1;
int vUseModernOrthography = 1;
int vRestoreIfWrongSpelling = 1;
int vFixRecommendBrowser = 1;
int vUseSmartSwitchKey = 0;
int vOtherLanguage = 0;
int vAutoSwitchByTyping = 1;

static std::vector<std::unique_ptr<VikeyDriver>> gDrivers;

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

static VikeyDriver *driverAt(int slot) {
    if (slot <= 0 || slot > static_cast<int>(gDrivers.size())) {
        return nullptr;
    }
    return gDrivers[static_cast<size_t>(slot - 1)].get();
}

static std::u16string utf16Of(napi_env env, napi_value value) {
    size_t len = 0;
    napi_get_value_string_utf16(env, value, nullptr, 0, &len);
    std::u16string out(len, 0);
    if (len > 0) {
        napi_get_value_string_utf16(env, value, reinterpret_cast<char16_t *>(out.data()), len + 1, &len);
    }
    return out;
}

static std::string utf8Of(napi_env env, napi_value value) {
    size_t len = 0;
    napi_get_value_string_utf8(env, value, nullptr, 0, &len);
    std::string out(len, 0);
    if (len > 0) {
        napi_get_value_string_utf8(env, value, out.data(), len + 1, &len);
    }
    return out;
}

static napi_value jsString16(napi_env env, const std::u16string &s) {
    napi_value out;
    napi_create_string_utf16(env, reinterpret_cast<const char16_t *>(s.data()), s.size(), &out);
    return out;
}

static std::u16string packEdit(const VKEdit &edit) {
    std::u16string s;
    s.push_back(static_cast<char16_t>(edit.deleteCount));
    s.push_back(static_cast<char16_t>(edit.languageChanged ? 1 : 0));
    s += edit.text;
    return s;
}

static int intOf(napi_env env, napi_value value) {
    int32_t n = 0;
    napi_get_value_int32(env, value, &n);
    return n;
}

static double doubleOf(napi_env env, napi_value value) {
    double n = 0;
    napi_get_value_double(env, value, &n);
    return n;
}

static bool boolOf(napi_env env, napi_value value) {
    bool n = false;
    napi_get_value_bool(env, value, &n);
    return n;
}

static napi_value arg(napi_env env, napi_callback_info info, size_t index, size_t *argcOut) {
    size_t argc = 12;
    napi_value argv[12];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argcOut != nullptr) {
        *argcOut = argc;
    }
    if (index >= argc) {
        napi_value undef;
        napi_get_undefined(env, &undef);
        return undef;
    }
    return argv[index];
}

static std::vector<double> doublesOf(napi_env env, napi_value array) {
    std::vector<double> out;
    bool isArray = false;
    napi_is_array(env, array, &isArray);
    if (!isArray) {
        return out;
    }
    uint32_t len = 0;
    napi_get_array_length(env, array, &len);
    out.reserve(len);
    for (uint32_t i = 0; i < len; i++) {
        napi_value item;
        napi_get_element(env, array, i, &item);
        out.push_back(doubleOf(env, item));
    }
    return out;
}

static std::vector<TMKey> keysOf(const std::string &letters, const std::vector<double> &rects) {
    std::vector<TMKey> keys;
    size_t n = letters.size();
    if (rects.size() < n * 4) {
        n = rects.size() / 4;
    }
    for (size_t i = 0; i < n; i++) {
        TMKey key = {};
        key.letter = letters[i];
        key.x = static_cast<float>(rects[i * 4]);
        key.y = static_cast<float>(rects[i * 4 + 1]);
        key.w = static_cast<float>(rects[i * 4 + 2]);
        key.h = static_cast<float>(rects[i * 4 + 3]);
        keys.push_back(key);
    }
    return keys;
}

static std::u16string packCandidate(const TMCandidate &c) {
    std::u16string s;
    for (const char *p = c.letters; *p; p++) {
        s.push_back(static_cast<char16_t>(*p));
    }
    s.push_back(u'\t');
    s.append(reinterpret_cast<const char16_t *>(c.text), static_cast<size_t>(c.textLen));
    s.push_back(u'\t');
    s.push_back(c.vietnamese ? u'1' : u'0');
    s.push_back(u'\t');
    std::string score = std::to_string(c.score);
    for (char ch : score) {
        s.push_back(static_cast<char16_t>(ch));
    }
    return s;
}

static napi_value packCandidates(napi_env env, const std::vector<TMCandidate> &list, int count) {
    napi_value out;
    napi_create_array_with_length(env, static_cast<size_t>(count), &out);
    for (int i = 0; i < count; i++) {
        napi_set_element(env, out, static_cast<uint32_t>(i), jsString16(env, packCandidate(list[static_cast<size_t>(i)])));
    }
    return out;
}

static void unpackCandidate(const std::u16string &s, TMCandidate &c) {
    int field = 0;
    int letters = 0;
    int text = 0;
    std::string score;
    for (char16_t ch : s) {
        if (ch == u'\t') {
            field++;
            continue;
        }
        if (field == 0 && letters < 31) {
            c.letters[letters++] = static_cast<char>(ch);
        } else if (field == 1 && text < 48) {
            c.text[text++] = ch;
        } else if (field == 2) {
            c.vietnamese = ch == u'1';
        } else if (field == 3) {
            score.push_back(static_cast<char>(ch));
        }
    }
    c.letters[letters] = 0;
    c.textLen = text;
    c.score = score.empty() ? 0 : std::atof(score.c_str());
}

static napi_value Create(napi_env env, napi_callback_info info) {
    auto driver = std::make_unique<VikeyDriver>();
    driver->pauseAfterManual = 5;
    gDrivers.push_back(std::move(driver));
    napi_value out;
    napi_create_int32(env, static_cast<int32_t>(gDrivers.size()), &out);
    return out;
}

static napi_value Destroy(napi_env env, napi_callback_info info) {
    int slot = intOf(env, arg(env, info, 0, nullptr));
    if (slot > 0 && slot <= static_cast<int>(gDrivers.size())) {
        gDrivers[static_cast<size_t>(slot - 1)].reset();
    }
    napi_value undef;
    napi_get_undefined(env, &undef);
    return undef;
}

static napi_value Language(napi_env env, napi_callback_info info) {
    napi_value out;
    napi_create_int32(env, vLanguage, &out);
    return out;
}

static napi_value SetLanguage(napi_env env, napi_callback_info info) {
    VikeyDriver *driver = driverAt(intOf(env, arg(env, info, 0, nullptr)));
    if (driver != nullptr) {
        driver->setLanguage(intOf(env, arg(env, info, 1, nullptr)));
    }
    napi_value undef;
    napi_get_undefined(env, &undef);
    return undef;
}

static napi_value Configure(napi_env env, napi_callback_info info) {
    VikeyDriver *driver = driverAt(intOf(env, arg(env, info, 0, nullptr)));
    if (driver != nullptr) {
        driver->autoSwitch = boolOf(env, arg(env, info, 1, nullptr));
        driver->pauseAfterManual = doubleOf(env, arg(env, info, 2, nullptr));
        vCheckSpelling = boolOf(env, arg(env, info, 3, nullptr)) ? 1 : 0;
        vSetCheckSpelling();
        vRestoreIfWrongSpelling = boolOf(env, arg(env, info, 4, nullptr)) ? 1 : 0;
        vUseModernOrthography = boolOf(env, arg(env, info, 5, nullptr)) ? 1 : 0;
    }
    napi_value undef;
    napi_get_undefined(env, &undef);
    return undef;
}

static napi_value SetTelexStyle(napi_env env, napi_callback_info info) {
    int style = intOf(env, arg(env, info, 0, nullptr));
    if (style < 0) {
        style = 0;
    }
    if (style > 2) {
        style = 2;
    }
    vTelexStyle = style;
    napi_value undef;
    napi_get_undefined(env, &undef);
    return undef;
}

static napi_value TypeChar(napi_env env, napi_callback_info info) {
    VikeyDriver *driver = driverAt(intOf(env, arg(env, info, 0, nullptr)));
    std::u16string text = utf16Of(env, arg(env, info, 1, nullptr));
    double now = doubleOf(env, arg(env, info, 2, nullptr));
    VKEdit edit;
    char16_t ch = text.empty() ? 0 : text[0];
    Uint16 key = 0;
    bool shift = false;
    if (driver == nullptr) {
        return jsString16(env, packEdit(edit));
    }
    if (!keyFor(ch, key, shift)) {
        driver->resetContext();
        if (ch != 0) {
            edit.text.push_back(ch);
        }
        return jsString16(env, packEdit(edit));
    }
    return jsString16(env, packEdit(driver->press(key, shift, now)));
}

static napi_value Backspace(napi_env env, napi_callback_info info) {
    VikeyDriver *driver = driverAt(intOf(env, arg(env, info, 0, nullptr)));
    double now = doubleOf(env, arg(env, info, 1, nullptr));
    VKEdit edit;
    if (driver != nullptr) {
        edit = driver->press(KEY_DELETE, false, now);
    }
    return jsString16(env, packEdit(edit));
}

static napi_value ManualSwitch(napi_env env, napi_callback_info info) {
    VikeyDriver *driver = driverAt(intOf(env, arg(env, info, 0, nullptr)));
    if (driver != nullptr) {
        driver->manualSwitch(doubleOf(env, arg(env, info, 1, nullptr)));
    }
    napi_value undef;
    napi_get_undefined(env, &undef);
    return undef;
}

static napi_value ResetContext(napi_env env, napi_callback_info info) {
    VikeyDriver *driver = driverAt(intOf(env, arg(env, info, 0, nullptr)));
    if (driver != nullptr) {
        driver->resetContext();
    }
    napi_value undef;
    napi_get_undefined(env, &undef);
    return undef;
}

static napi_value PickLetter(napi_env env, napi_callback_info info) {
    float x = static_cast<float>(doubleOf(env, arg(env, info, 0, nullptr)));
    float y = static_cast<float>(doubleOf(env, arg(env, info, 1, nullptr)));
    std::string prefix = utf8Of(env, arg(env, info, 2, nullptr));
    int vi = intOf(env, arg(env, info, 3, nullptr));
    std::string letters = utf8Of(env, arg(env, info, 4, nullptr));
    std::vector<TMKey> keys = keysOf(letters, doublesOf(env, arg(env, info, 5, nullptr)));
    char picked = 0;
    if (!keys.empty()) {
        picked = TouchModel::pick(x, y, prefix.c_str(), vi, keys.data(), static_cast<int>(keys.size()));
    }
    napi_value out;
    napi_create_int32(env, static_cast<unsigned char>(picked), &out);
    return out;
}

static napi_value Candidates(napi_env env, napi_callback_info info) {
    std::string typed = utf8Of(env, arg(env, info, 0, nullptr));
    std::vector<double> xs = doublesOf(env, arg(env, info, 1, nullptr));
    std::vector<double> ys = doublesOf(env, arg(env, info, 2, nullptr));
    int vi = intOf(env, arg(env, info, 3, nullptr));
    std::string letters = utf8Of(env, arg(env, info, 4, nullptr));
    std::vector<TMKey> keys = keysOf(letters, doublesOf(env, arg(env, info, 5, nullptr)));
    int max = intOf(env, arg(env, info, 6, nullptr));
    if (max < 1) {
        max = 1;
    }
    if (max > 8) {
        max = 8;
    }
    std::vector<TMCandidate> list(static_cast<size_t>(max));
    std::vector<float> fx(xs.size());
    std::vector<float> fy(ys.size());
    for (size_t i = 0; i < xs.size(); i++) {
        fx[i] = static_cast<float>(xs[i]);
    }
    for (size_t i = 0; i < ys.size(); i++) {
        fy[i] = static_cast<float>(ys[i]);
    }
    int count = 0;
    if (!keys.empty()) {
        count = TouchModel::candidates(typed.c_str(), fx.empty() ? nullptr : fx.data(), fy.empty() ? nullptr : fy.data(),
            vi, keys.data(), static_cast<int>(keys.size()), list.data(), max);
    }
    return packCandidates(env, list, count);
}

static napi_value ShouldCorrect(napi_env env, napi_callback_info info) {
    std::string typed = utf8Of(env, arg(env, info, 0, nullptr));
    napi_value array = arg(env, info, 1, nullptr);
    std::vector<TMCandidate> list;
    bool isArray = false;
    napi_is_array(env, array, &isArray);
    if (isArray) {
        uint32_t len = 0;
        napi_get_array_length(env, array, &len);
        list.resize(len);
        for (uint32_t i = 0; i < len; i++) {
            napi_value item;
            napi_get_element(env, array, i, &item);
            unpackCandidate(utf16Of(env, item), list[i]);
        }
    }
    bool yes = TouchModel::shouldCorrect(typed.c_str(), list.empty() ? nullptr : list.data(), static_cast<int>(list.size()));
    napi_value out;
    napi_get_boolean(env, yes, &out);
    return out;
}

static napi_value Completions(napi_env env, napi_callback_info info) {
    std::string prefix = utf8Of(env, arg(env, info, 0, nullptr));
    int vi = intOf(env, arg(env, info, 1, nullptr));
    int max = intOf(env, arg(env, info, 2, nullptr));
    if (max < 1) {
        max = 1;
    }
    std::vector<TMCandidate> out;
    for (int pass = 0; pass < 2; pass++) {
        int lang = pass == 0 ? vi : !vi;
        char words[8][32];
        int scores[8];
        int count = vAutoSwitchCompletions(lang, prefix.c_str(), words, scores, 8);
        for (int i = 0; i < count && static_cast<int>(out.size()) < max; i++) {
            TMCandidate candidate = {};
            strncpy(candidate.letters, words[i], 31);
            int len = 0;
            if (vAutoSwitchWordScore(lang, words[i], reinterpret_cast<Uint16 *>(candidate.text), &len) <= -1000 || len <= 0) {
                continue;
            }
            candidate.textLen = len;
            candidate.vietnamese = lang;
            candidate.score = scores[i] / 10.0 * 2.302585 + (pass == 0 ? 0 : -1.5);
            bool duplicate = false;
            for (const TMCandidate &have : out) {
                if (have.textLen == len && memcmp(have.text, candidate.text, static_cast<size_t>(len) * 2) == 0) {
                    duplicate = true;
                }
            }
            if (!duplicate) {
                out.push_back(candidate);
            }
        }
    }
    for (size_t i = 1; i < out.size(); i++) {
        for (size_t j = i; j > 0 && out[j].score > out[j - 1].score; j--) {
            std::swap(out[j], out[j - 1]);
        }
    }
    return packCandidates(env, out, static_cast<int>(out.size()));
}

static napi_value WordScore(napi_env env, napi_callback_info info) {
    int vi = intOf(env, arg(env, info, 0, nullptr));
    std::string letters = utf8Of(env, arg(env, info, 1, nullptr));
    int score = vAutoSwitchWordScore(vi, letters.c_str(), nullptr, nullptr);
    napi_value out;
    napi_create_int32(env, score, &out);
    return out;
}

static napi_value AccentForms(napi_env env, napi_callback_info info) {
    std::string typed = utf8Of(env, arg(env, info, 0, nullptr));
    int maxOut = intOf(env, arg(env, info, 1, nullptr));
    if (maxOut < 1) maxOut = 1;
    if (maxOut > 8) maxOut = 8;
    Uint16 words[8][48];
    int lens[8];
    int scores[8];
    int count = vAccentForms(typed.c_str(), words, lens, scores, maxOut);
    napi_value out;
    napi_create_array_with_length(env, static_cast<size_t>(count), &out);
    for (int i = 0; i < count; i++) {
        std::u16string text;
        for (int c = 0; c < lens[i]; c++) text.push_back(static_cast<char16_t>(words[i][c]));
        napi_set_element(env, out, static_cast<uint32_t>(i), jsString16(env, text));
    }
    return out;
}

static void exportFn(napi_env env, napi_value exports, const char *name, napi_callback cb) {
    napi_property_descriptor desc = {name, nullptr, cb, nullptr, nullptr, nullptr, napi_default, nullptr};
    napi_define_properties(env, exports, 1, &desc);
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    exportFn(env, exports, "create", Create);
    exportFn(env, exports, "destroy", Destroy);
    exportFn(env, exports, "language", Language);
    exportFn(env, exports, "setLanguage", SetLanguage);
    exportFn(env, exports, "configure", Configure);
    exportFn(env, exports, "setTelexStyle", SetTelexStyle);
    exportFn(env, exports, "typeChar", TypeChar);
    exportFn(env, exports, "backspace", Backspace);
    exportFn(env, exports, "manualSwitch", ManualSwitch);
    exportFn(env, exports, "resetContext", ResetContext);
    exportFn(env, exports, "pickLetter", PickLetter);
    exportFn(env, exports, "candidates", Candidates);
    exportFn(env, exports, "shouldCorrect", ShouldCorrect);
    exportFn(env, exports, "completions", Completions);
    exportFn(env, exports, "wordScore", WordScore);
    exportFn(env, exports, "accentForms", AccentForms);
    return exports;
}
EXTERN_C_END

static napi_module vikeyModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "vikey",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterVikeyModule(void) {
    napi_module_register(&vikeyModule);
}
