#include "raylib.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

extern "C" {

    void AddTraffic(int lane);
    void StepTick(void);
    void SaveReport(void);

    extern uint8_t  lights_state;
    extern uint8_t  current_phase;
    extern uint32_t phase_timer;

    extern uint32_t north_queue, south_queue, east_queue, west_queue;
    extern uint32_t total_in, total_out, current_cars, peak_queue;
    extern uint32_t ticks;
    extern uint32_t north_departs, east_departs, south_departs, west_departs;
    extern uint32_t total_north_cars, total_south_cars, total_east_cars, total_west_cars;
    extern uint32_t max_north_queue, max_south_queue, max_east_queue, max_west_queue;
    extern uint32_t time_max_queue;
    extern uint32_t time_max_north_queue, time_max_south_queue;
    extern uint32_t time_max_east_queue, time_max_west_queue;
    extern char     phase_names[];
}

enum Lane { LANE_N = 0, LANE_E = 1, LANE_S = 2, LANE_W = 3 };

static uint32_t Queue(int L)
{
    switch (L) {
    case LANE_N: return north_queue; case LANE_E: return east_queue;
    case LANE_S: return south_queue; default:     return west_queue;
    }
}
static uint32_t Departs(int L)
{
    switch (L) {
    case LANE_N: return north_departs; case LANE_E: return east_departs;
    case LANE_S: return south_departs; default:     return west_departs;
    }
}

static int LaneLight(int L)
{
    static const uint8_t GREEN_BIT[4] = { 0x01, 0x04, 0x10, 0x40 };
    if (lights_state & GREEN_BIT[L])        return 2;
    if (lights_state & (GREEN_BIT[L] << 1)) return 1;
    return 0;
}
static std::string PhaseName(int idx)
{
    std::string s(phase_names + (idx & 7) * 14);
    while (!s.empty() && s.back() == ' ') s.pop_back();
    return s;
}

constexpr int   WIN_W = 1200, WIN_H = 750;
constexpr float TOOLBAR_Y = 686.0f;

constexpr float SCENE_X = 16, SCENE_Y = 52, SCENE_W = 608, SCENE_H = 618;
constexpr float CX = SCENE_X + SCENE_W / 2;
constexpr float CY = SCENE_Y + SCENE_H / 2;
constexpr float ROAD_HALF = 60;
constexpr float CAR_L = 26, CAR_W = 15, SLOT = 32;
constexpr float STOP_DIST = 76;
constexpr float FRONT_DIST = 93;
constexpr float SPAWN_S = 270;
constexpr int   MAXVIS = 7;

constexpr Vector2 APPROACH[4] = { {0,-1}, {1,0}, {0,1}, {-1,0} };
constexpr Vector2 LANE_OFF[4] = { {-30,0}, {0,-30}, {30,0}, {0,30} };

struct Theme {
    Color bg, card, border, text, sub, toolbar, btn, btnHover;
    Color grassA, grassB, asphalt, asphalt2, kerb, tree, treeHi, overlay;
    bool  night;
};
static const Theme NIGHT_T = {
    {13,15,21,255},  {24,28,38,255},  {44,50,66,255},  {236,239,246,255}, {138,148,170,255},
    {18,21,29,255},  {40,46,62,255},  {56,64,88,255},
    {24,52,38,255},  {28,60,43,255},  {44,46,54,255},  {50,52,61,255}, {96,99,110,255},
    {16,40,28,255},  {30,70,48,255},  {6,10,38,92},
    true };
static const Theme DAY_T = {
    {231,235,243,255}, {255,255,255,255}, {208,214,227,255}, {28,34,46,255}, {104,114,134,255},
    {246,248,252,255}, {226,231,241,255}, {208,216,232,255},
    {110,184,98,255},  {120,194,106,255}, {82,85,94,255}, {90,93,103,255}, {176,178,186,255},
    {62,140,70,255},   {96,170,92,255},   {0,0,0,0},
    false };

static const Color COL_GREEN = { 46, 204, 113, 255 };
static const Color COL_YELLOW = { 248, 200,  40, 255 };
static const Color COL_RED = { 240,  70,  60, 255 };
static const Color LANE_COL[4] = { {90,170,255,255}, {190,120,255,255}, {40,220,190,255}, {255,110,160,255} };
static const Color CAR_COLS[8] = { {235,87,87,255}, {86,156,255,255}, {250,205,80,255}, {120,220,150,255},
                                   {205,205,215,255}, {180,120,255,255}, {255,150,70,255}, {70,200,200,255} };

static Color LightCol(int st) { return st == 2 ? COL_GREEN : (st == 1 ? COL_YELLOW : COL_RED); }

static bool  gPaused = false, gNight = true, gQuit = false;
static int   gSpeedIdx = 0;
static const int   SPEEDS[3] = { 1, 2, 4 };
static float gAcc = 0.0f;
static float gFlash[4] = { 0, 0, 0, 0 };

constexpr int HN = 90;
static uint32_t gHist[4][HN];
static int      gHistCount = 0;

static const Theme& TH() { return gNight ? NIGHT_T : DAY_T; }

static void PushHistory()
{
    if (gHistCount < HN) {
        for (int L = 0; L < 4; ++L) gHist[L][gHistCount] = Queue(L);
        ++gHistCount;
    }
    else {
        for (int L = 0; L < 4; ++L) {
            std::memmove(&gHist[L][0], &gHist[L][1], (HN - 1) * sizeof(uint32_t));
            gHist[L][HN - 1] = Queue(L);
        }
    }
}
static void DoTick() { StepTick(); PushHistory(); }
static void PressLane(int L) { AddTraffic(L); gFlash[L] = 0.35f; }
static void SaveAndExit() { SaveReport(); gQuit = true; }

static Font gReg, gBold;
static bool gTTF = false;

static float Spc(float size) { return gTTF ? 0.4f : size / 10.0f; }
static void  Txt(const char* s, float x, float y, float size, Color c, bool bold = false)
{
    DrawTextEx(bold ? gBold : gReg, s, Vector2{ x, y }, size, Spc(size), c);
}
static float TxtW(const char* s, float size, bool bold = false)
{
    return MeasureTextEx(bold ? gBold : gReg, s, size, Spc(size)).x;
}
static void TxtR(const char* s, float xr, float y, float size, Color c, bool bold = false)
{
    Txt(s, xr - TxtW(s, size, bold), y, size, c, bold);
}
static void TxtC(const char* s, float xc, float y, float size, Color c, bool bold = false)
{
    Txt(s, xc - TxtW(s, size, bold) * 0.5f, y, size, c, bold);
}

static void LoadFonts()
{
    gReg = GetFontDefault(); gBold = gReg;
    const char* r = "C:/Windows/Fonts/segoeui.ttf";
    const char* b = "C:/Windows/Fonts/segoeuib.ttf";
    if (FileExists(r)) {
        Font f = LoadFontEx(r, 40, nullptr, 0);
        if (f.texture.id != 0) {
            gReg = f; gBold = f; gTTF = true;
            SetTextureFilter(gReg.texture, TEXTURE_FILTER_BILINEAR);
            if (FileExists(b)) {
                Font fb = LoadFontEx(b, 40, nullptr, 0);
                if (fb.texture.id != 0) { gBold = fb; SetTextureFilter(gBold.texture, TEXTURE_FILTER_BILINEAR); }
            }
        }
    }
}
static void UnloadFonts()
{
    if (gTTF) { if (gBold.texture.id != gReg.texture.id) UnloadFont(gBold); UnloadFont(gReg); }
}

static void RR(Rectangle r, float radius, Color c)
{
    float m = std::min(r.width, r.height) * 0.5f;
    float k = (m > 0.0f) ? std::min(1.0f, radius / m) : 0.0f;
    DrawRectangleRounded(r, k, 10, c);
}
static void Card(Rectangle r, Color fill, Color border, float radius = 12.0f)
{
    RR(r, radius, border);
    RR(Rectangle{ r.x + 1.5f, r.y + 1.5f, r.width - 3.0f, r.height - 3.0f }, radius - 1.5f, fill);
}
static bool Hover(Rectangle r) { return CheckCollisionPointRec(GetMousePosition(), r); }
static bool Clicked(Rectangle r) { return IsMouseButtonPressed(MOUSE_BUTTON_LEFT) && Hover(r); }

static void DrawBtn(Rectangle r, const char* label, Color base, Color hov, Color txt, float size = 15.0f)
{
    RR(Rectangle{ r.x, r.y + 2.0f, r.width, r.height }, 10, Fade(BLACK, 0.25f));
    RR(r, 10, Hover(r) ? hov : base);
    TxtC(label, r.x + r.width * 0.5f, r.y + (r.height - size) * 0.5f - 1.0f, size, txt, true);
}

static Rectangle BtnPause() { return Rectangle{ 16, 698, 132, 40 }; }
static Rectangle BtnTick() { return Rectangle{ 158, 698, 162, 40 }; }
static Rectangle BtnSpeed(int i) { return Rectangle{ 330.0f + i * 62.0f, 698, 58, 40 }; }
static Rectangle BtnTheme() { return Rectangle{ 524, 698, 136, 40 }; }
static Rectangle BtnSave() { return Rectangle{ 1016, 698, 168, 40 }; }
static Rectangle BtnAdd(int L)
{
    switch (L) {
    case LANE_N: return Rectangle{ CX - ROAD_HALF - 8 - 108, SCENE_Y + 10, 108, 30 };
    case LANE_E: return Rectangle{ SCENE_X + SCENE_W - 8 - 108, CY - STOP_DIST - 26, 108, 30 };
    case LANE_S: return Rectangle{ CX + STOP_DIST - 8, SCENE_Y + SCENE_H - 40, 108, 30 };
    default:     return Rectangle{ SCENE_X + 8, CY + STOP_DIST - 8, 108, 30 };
    }
}

struct VCar { float s, target, u, v; Color col; };
struct LaneVis { std::vector<VCar> q, out; uint32_t knownDep = 0; };
static LaneVis gLane[4];

static VCar NewCar(float s)
{
    VCar c; c.s = s; c.target = s; c.u = 0; c.v = 0;
    c.col = CAR_COLS[GetRandomValue(0, 7)];
    return c;
}
static Vector2 CarPos(int L, float dist)
{
    return Vector2{ CX + LANE_OFF[L].x + APPROACH[L].x * dist,
                    CY + LANE_OFF[L].y + APPROACH[L].y * dist };
}

static void SyncLane(int L)
{
    LaneVis& lv = gLane[L];
    uint32_t dep = Departs(L), cur = Queue(L);
    if (dep < lv.knownDep) lv.knownDep = dep;
    uint32_t n = dep - lv.knownDep;
    lv.knownDep = dep;

    for (uint32_t i = 0; i < n && i < 16; ++i) {
        VCar c;
        if (lv.q.empty()) c = NewCar(SPAWN_S);
        else { c = lv.q.front(); lv.q.erase(lv.q.begin()); }
        c.u = -c.s; c.v = 110.0f;
        lv.out.push_back(c);
    }
    size_t want = std::min<uint32_t>(cur, (uint32_t)MAXVIS);
    while (lv.q.size() > want) lv.q.pop_back();
    while (lv.q.size() < want) {
        float s = SPAWN_S;
        if (!lv.q.empty()) s = std::max(s, lv.q.back().s + SLOT);
        lv.q.push_back(NewCar(s));
    }
    for (size_t i = 0; i < lv.q.size(); ++i) lv.q[i].target = (float)i * SLOT;
}

static void UpdateVis(float dt, float anim)
{
    float k = dt * anim;
    for (int L = 0; L < 4; ++L) {
        LaneVis& lv = gLane[L];
        for (VCar& c : lv.q) {
            if (c.s > c.target) {
                float d = c.s - c.target;
                float sp = std::min(200.0f, std::max(50.0f, d * 3.0f));
                c.s = std::max(c.target, c.s - sp * k);
            }
            else c.s = c.target;
        }
        for (VCar& c : lv.out) { c.v = std::min(420.0f, c.v + 420.0f * k); c.u += c.v * k; }
        lv.out.erase(std::remove_if(lv.out.begin(), lv.out.end(),
            [](const VCar& c) { return c.u > 440.0f; }), lv.out.end());
    }
}

static void DrawCar(Vector2 c, Vector2 dir, Color body, bool braking, bool night)
{
    bool horiz = std::fabs(dir.x) > 0.5f;
    float w = horiz ? CAR_L : CAR_W, h = horiz ? CAR_W : CAR_L;
    Rectangle b = { c.x - w * 0.5f, c.y - h * 0.5f, w, h };
    RR(Rectangle{ b.x + 1.5f, b.y + 2.0f, b.width, b.height }, 5, Fade(BLACK, 0.35f));
    RR(b, 5, body);

    Vector2 cc = { c.x + dir.x * 1.5f, c.y + dir.y * 1.5f };
    Rectangle cab = horiz ? Rectangle{ cc.x - 5.0f, cc.y - 5.5f, 10, 11 }
    : Rectangle{ cc.x - 5.5f, cc.y - 5.0f, 11, 10 };
    RR(cab, 3, Color{ 18, 22, 32, 210 });

    Vector2 perp = { -dir.y, dir.x };
    Vector2 front = { c.x + dir.x * 12.5f, c.y + dir.y * 12.5f };
    Vector2 rear = { c.x - dir.x * 12.5f, c.y - dir.y * 12.5f };
    Color head = Color{ 255, 248, 200, 255 };
    for (int sgn = -1; sgn <= 1; sgn += 2) {
        Vector2 hp = { front.x + perp.x * 4.5f * sgn, front.y + perp.y * 4.5f * sgn };
        Vector2 tp = { rear.x + perp.x * 4.5f * sgn, rear.y + perp.y * 4.5f * sgn };
        if (night) DrawCircleV(hp, 7.0f, Fade(head, 0.20f));
        DrawCircleV(hp, 2.0f, head);
        if (braking) DrawCircleV(tp, 4.5f, Fade(COL_RED, 0.30f));
        DrawCircleV(tp, 1.9f, braking ? Color{ 255, 70, 60, 255 } : Color{ 150, 40, 40, 255 });
    }
}

static void DrawVehicles(const Theme& T)
{
    for (int L = 0; L < 4; ++L) {
        LaneVis& lv = gLane[L];
        Vector2 dir = { -APPROACH[L].x, -APPROACH[L].y };
        for (const VCar& c : lv.q) {
            bool stopped = (c.s - c.target) < 1.0f;
            DrawCar(CarPos(L, FRONT_DIST + c.s), dir, c.col, stopped, T.night);
        }
        for (const VCar& c : lv.out)
            DrawCar(CarPos(L, FRONT_DIST - c.u), dir, c.col, false, T.night);

        uint32_t qn = Queue(L);
        if (qn > (uint32_t)MAXVIS && !lv.q.empty()) {
            Vector2 p = CarPos(L, FRONT_DIST + lv.q.back().target);
            char b[16]; std::snprintf(b, sizeof b, "+%u", qn - MAXVIS);
            float tw = TxtW(b, 12, true);
            RR(Rectangle{ p.x - tw * 0.5f - 6, p.y - 9, tw + 12, 18 }, 9, Color{ 12, 14, 20, 225 });
            TxtC(b, p.x, p.y - 7, 12, WHITE, true);
        }
    }
}

static void DrawSignal(Vector2 c, int st, const char* label, const Theme& T)
{
    Rectangle h = { c.x - 12, c.y - 31, 24, 62 };
    RR(Rectangle{ h.x - 2, h.y, h.width + 4, h.height + 4 }, 9, Fade(BLACK, 0.35f));
    RR(h, 8, Color{ 22, 24, 30, 255 });
    Color cols[3] = { COL_RED, COL_YELLOW, COL_GREEN };
    for (int i = 0; i < 3; ++i) {
        Vector2 p = { c.x, h.y + 12 + 19.0f * i };
        bool on = (i == 0 && st == 0) || (i == 1 && st == 1) || (i == 2 && st == 2);
        if (on) {
            DrawCircleV(p, 19, Fade(cols[i], 0.10f));
            DrawCircleV(p, 15, Fade(cols[i], 0.18f));
            DrawCircleV(p, 9, cols[i]);
            DrawCircleV(Vector2{ p.x - 2.5f, p.y - 2.5f }, 3, Fade(WHITE, 0.55f));
        }
        else {
            DrawCircleV(p, 8, Fade(cols[i], 0.16f));
        }
    }
    TxtC(label, c.x, h.y - 19, 14, T.night ? Color{ 235, 238, 246, 255 } : Color{ 20, 28, 40, 255 }, true);
}

static void DrawScene(const Theme& T)
{
    auto R = [](float x, float y, float w, float h, Color c) { DrawRectangleRec(Rectangle{ x, y, w, h }, c); };
    const float L = SCENE_X, Tp = SCENE_Y, Rt = SCENE_X + SCENE_W, Bt = SCENE_Y + SCENE_H;
    const float rl = CX - ROAD_HALF, rr = CX + ROAD_HALF, rt = CY - ROAD_HALF, rb = CY + ROAD_HALF;

    BeginScissorMode((int)SCENE_X, (int)SCENE_Y, (int)SCENE_W, (int)SCENE_H);

    R(L, Tp, SCENE_W, SCENE_H, T.grassA);
    R(rr, Tp, Rt - rr, rt - Tp, T.grassB);
    R(L, rb, rl - L, Bt - rb, T.grassB);

    static const float TREES[][3] = {
        { 60,130,18 }, { 130,205,22 }, { 205,135,16 },
        { 470,110,20 }, { 575,170,22 }, { 540,235,16 },
        { 560,500,20 }, { 470,590,22 }, { 590,610,16 },
        { 70,520,20 }, { 150,590,22 }, { 220,520,16 } };
    for (const auto& t : TREES) {
        DrawCircleV(Vector2{ t[0] + 3, t[1] + 4 }, t[2], Fade(BLACK, 0.22f));
        DrawCircleV(Vector2{ t[0], t[1] }, t[2], T.tree);
        DrawCircleV(Vector2{ t[0] - t[2] * 0.25f, t[1] - t[2] * 0.25f }, t[2] * 0.55f, T.treeHi);
    }

    R(rl, Tp, 2 * ROAD_HALF, SCENE_H, T.asphalt);
    R(L, rt, SCENE_W, 2 * ROAD_HALF, T.asphalt);
    R(rl, rt, 2 * ROAD_HALF, 2 * ROAD_HALF, T.asphalt2);
    const float k = 4;
    R(rl - k, Tp, k, rt - Tp, T.kerb);   R(rl - k, rb, k, Bt - rb, T.kerb);
    R(rr, Tp, k, rt - Tp, T.kerb);   R(rr, rb, k, Bt - rb, T.kerb);
    R(L, rt - k, rl - L, k, T.kerb);     R(rr, rt - k, Rt - rr, k, T.kerb);
    R(L, rb, rl - L, k, T.kerb);     R(rr, rb, Rt - rr, k, T.kerb);

    const Color Y = { 245, 190, 40, 255 };
    const Color Wl = Fade(WHITE, 0.55f);
    const float arm = 82;
    R(CX - 3, Tp, 2, CY - arm - Tp, Y);  R(CX + 1, Tp, 2, CY - arm - Tp, Y);
    R(CX - 3, CY + arm, 2, Bt - CY - arm, Y);  R(CX + 1, CY + arm, 2, Bt - CY - arm, Y);
    R(L, CY - 3, CX - arm - L, 2, Y);    R(L, CY + 1, CX - arm - L, 2, Y);
    R(CX + arm, CY - 3, Rt - CX - arm, 2, Y);  R(CX + arm, CY + 1, Rt - CX - arm, 2, Y);
    R(CX - 55, Tp, 2, CY - arm - Tp, Wl);  R(CX + 53, Tp, 2, CY - arm - Tp, Wl);
    R(CX - 55, CY + arm, 2, Bt - CY - arm, Wl);  R(CX + 53, CY + arm, 2, Bt - CY - arm, Wl);
    R(L, CY - 55, CX - arm - L, 2, Wl);  R(L, CY + 53, CX - arm - L, 2, Wl);
    R(CX + arm, CY - 55, Rt - CX - arm, 2, Wl);  R(CX + arm, CY + 53, Rt - CX - arm, 2, Wl);

    const Color Zc = Fade(WHITE, 0.85f);
    for (int i = 0; i < 8; ++i) {
        float o = -53.0f + 14.0f * i;
        R(CX + o, CY - 72, 8, 10, Zc);  R(CX + o, CY + 62, 8, 10, Zc);
        R(CX + 62, CY + o, 10, 8, Zc);  R(CX - 72, CY + o, 10, 8, Zc);
    }

    R(CX - ROAD_HALF, CY - STOP_DIST - 4, ROAD_HALF, 4, WHITE);
    R(CX + STOP_DIST, CY - ROAD_HALF, 4, ROAD_HALF, WHITE);
    R(CX, CY + STOP_DIST, ROAD_HALF, 4, WHITE);
    R(CX - STOP_DIST - 4, CY, 4, ROAD_HALF, WHITE);

    if (T.night) R(L, Tp, SCENE_W, SCENE_H, T.overlay);

    DrawVehicles(T);
    EndScissorMode();

    static const Vector2 SIG[4] = { { CX - 95, CY - 100 }, { CX + 100, CY - 95 },
                                    { CX + 95, CY + 100 }, { CX - 100, CY + 95 } };
    static const char* LBL[4] = { "N", "E", "S", "W" };
    for (int i = 0; i < 4; ++i) DrawSignal(SIG[i], LaneLight(i), LBL[i], T);

    static const char* ADD[4] = { "+1 North [N]", "+1 East [E]", "+1 South [S]", "+1 West [W]" };
    for (int i = 0; i < 4; ++i) {
        Rectangle r = BtnAdd(i);
        Color fill = Hover(r) ? T.btnHover : T.btn;
        Card(r, Fade(fill, 0.96f), LANE_COL[i], 9);
        if (gFlash[i] > 0) RR(r, 9, Fade(LANE_COL[i], std::min(0.8f, gFlash[i] * 2.2f)));
        TxtC(ADD[i], r.x + r.width * 0.5f, r.y + 7, 14, T.text, true);
    }
}

static void DrawLeftPanel(const Theme& T)
{
    Card(Rectangle{ 8, 8, 624, 670 }, T.card, T.border, 16);
    Txt("LIVE INTERSECTION", 28, 17, 17, T.text, true);

    char sb[32];
    if (gPaused) std::snprintf(sb, sizeof sb, "PAUSED");
    else         std::snprintf(sb, sizeof sb, "RUNNING %dx", SPEEDS[gSpeedIdx]);
    Color pc = gPaused ? COL_YELLOW : COL_GREEN;
    float px = 28 + TxtW("LIVE INTERSECTION", 17, true) + 14;
    Rectangle pill = { px, 15, TxtW(sb, 11, true) + 28, 22 };
    RR(pill, 11, Fade(pc, 0.20f));
    DrawCircleV(Vector2{ pill.x + 12, pill.y + 11 }, 4, pc);
    Txt(sb, pill.x + 22, pill.y + 4, 11, pc, true);

    uint32_t t = ticks;
    char tb[64];
    std::snprintf(tb, sizeof tb, "System Time %02u:%02u:%02u   |   Tick %u", t / 3600, (t % 3600) / 60, t % 60, t);
    TxtR(tb, 620, 19, 14, T.sub);

    DrawScene(T);
}

static void DrawBanner(Rectangle r, const Theme& T)
{
    int  ph = current_phase & 7;
    bool yellow = (ph & 1) != 0;
    Color lc = yellow ? COL_YELLOW : COL_GREEN;

    Card(r, T.card, Fade(lc, 0.60f), 14);
    RR(Rectangle{ r.x + 1.5f, r.y + 1.5f, r.width - 3, r.height - 3 }, 12.5f, Fade(lc, T.night ? 0.12f : 0.16f));

    Vector2 lp = { r.x + 44, r.y + r.height * 0.5f };
    DrawCircleV(lp, 31, Fade(lc, 0.10f));
    DrawCircleV(lp, 24, Fade(lc, 0.20f));
    DrawCircleV(lp, 16, lc);
    DrawCircleV(Vector2{ lp.x - 5, lp.y - 5 }, 4, Fade(WHITE, 0.55f));

    Txt("ACTIVE SIGNAL", r.x + 86, r.y + 11, 12, T.sub, true);
    Txt(PhaseName(ph).c_str(), r.x + 86, r.y + 26, 28, lc, true);
    std::string nx = "Next: " + PhaseName((ph + 1) & 7);
    Txt(nx.c_str(), r.x + 86, r.y + 61, 13, T.sub);

    char b[24]; std::snprintf(b, sizeof b, "%us", phase_timer);
    TxtR("TIMER", r.x + r.width - 22, r.y + 11, 12, T.sub, true);
    TxtR(b, r.x + r.width - 22, r.y + 25, 42, T.text, true);
}

static void DrawLaneCard(int L, Rectangle r, const Theme& T)
{
    static const char* NAMES[4] = { "NORTH", "EAST", "SOUTH", "WEST" };
    int   st = LaneLight(L);
    Color lc = LightCol(st);
    Card(r, T.card, st > 0 ? Fade(lc, 0.85f) : T.border, 14);

    RR(Rectangle{ r.x + 12, r.y + 14, 4, 22 }, 2, LANE_COL[L]);
    Txt(NAMES[L], r.x + 24, r.y + 13, 17, T.text, true);

    const char* sn = st == 2 ? "GREEN" : (st == 1 ? "YELLOW" : "RED");
    Rectangle pill = { r.x + r.width - 14 - 78, r.y + 13, 78, 22 };
    RR(pill, 11, Fade(lc, 0.20f));
    DrawCircleV(Vector2{ pill.x + 12, pill.y + 11 }, 4, lc);
    Txt(sn, pill.x + 23, pill.y + 4, 12, lc, true);

    float mid = r.x + r.width * 0.5f;
    DrawLineEx(Vector2{ mid, r.y + 44 }, Vector2{ mid, r.y + 86 }, 1.0f, T.border);

    char b[24];
    std::snprintf(b, sizeof b, "%u", Queue(L));
    Txt(b, r.x + 16, r.y + 39, 32, T.text, true);
    Txt("Queued", r.x + 16, r.y + 76, 12, T.sub);
    std::snprintf(b, sizeof b, "%u", Departs(L));
    Txt(b, mid + 14, r.y + 39, 32, T.text, true);
    Txt("Departed", mid + 14, r.y + 76, 12, T.sub);
}

static uint32_t NiceStep(uint32_t m)
{
    for (uint32_t p = 1; ; p *= 10)
        for (uint32_t mult : { 1u, 2u, 5u })
            if (4u * mult * p >= m) return mult * p;
}

static void DrawChart(Rectangle r, const Theme& T)
{
    static const char* NAMES[4] = { "North", "East", "South", "West" };
    Card(r, T.card, T.border, 14);
    Txt("Queue History (last 90 ticks)", r.x + 16, r.y + 10, 16, T.text, true);
    for (int i = 0; i < 4; ++i) {
        float lx = r.x + r.width - 16 - (4 - i) * 62.0f + 8;
        DrawCircleV(Vector2{ lx + 4, r.y + 20 }, 4.5f, LANE_COL[i]);
        Txt(NAMES[i], lx + 13, r.y + 12, 12, T.sub);
    }

    Rectangle pl = { r.x + 50, r.y + 44, r.width - 50 - 18, r.height - 44 - 30 };
    uint32_t mx = 5;
    for (int L = 0; L < 4; ++L) for (int i = 0; i < gHistCount; ++i) mx = std::max(mx, gHist[L][i]);
    uint32_t step = NiceStep(mx), top = step * 4;

    for (int i = 0; i <= 4; ++i) {
        float y = pl.y + pl.height - pl.height * i / 4.0f;
        DrawLineEx(Vector2{ pl.x, y }, Vector2{ pl.x + pl.width, y }, 1.0f, Fade(T.sub, 0.22f));
        char b[16]; std::snprintf(b, sizeof b, "%u", step * i);
        TxtR(b, pl.x - 8, y - 7, 11, T.sub);
    }
    TxtC("-90", pl.x, pl.y + pl.height + 7, 11, T.sub);
    TxtC("-45", pl.x + pl.width * 0.5f, pl.y + pl.height + 7, 11, T.sub);
    TxtC("now", pl.x + pl.width, pl.y + pl.height + 7, 11, T.sub);

    if (gHistCount < 2) { TxtC("collecting data...", pl.x + pl.width * 0.5f, pl.y + pl.height * 0.5f - 8, 13, T.sub); return; }

    float dx = pl.width / (float)(HN - 1);
    for (int L = 0; L < 4; ++L) {
        Vector2 prev = { 0, 0 };
        for (int i = 0; i < gHistCount; ++i) {
            Vector2 p = { pl.x + pl.width - (float)(gHistCount - 1 - i) * dx,
                          pl.y + pl.height - pl.height * (float)gHist[L][i] / (float)top };
            if (i > 0) DrawLineEx(prev, p, 2.2f, LANE_COL[L]);
            prev = p;
        }
        DrawCircleV(prev, 3.2f, LANE_COL[L]);
    }
}

static void DrawStats(Rectangle r, const Theme& T)
{
    Card(r, T.card, T.border, 14);
    Txt("Statistics (Saved to traffic.txt)", r.x + 16, r.y + 9, 16, T.text, true);

    char b[96];
    std::snprintf(b, sizeof b, "Total in  %u", total_in);                       Txt(b, r.x + 16, r.y + 33, 13, T.text);
    std::snprintf(b, sizeof b, "Total out  %u", total_out);                     Txt(b, r.x + 150, r.y + 33, 13, T.text);
    std::snprintf(b, sizeof b, "Peak queue  %u (tick %u)", peak_queue, time_max_queue);
    Txt(b, r.x + 290, r.y + 33, 13, T.text);
    std::snprintf(b, sizeof b, "Busiest lane now  %u", current_cars);           Txt(b, r.x + 16, r.y + 52, 13, T.sub);

    const char* hd[4] = { "North", "East", "South", "West" };
    float cx0 = r.x + 170, cw = 88;
    for (int i = 0; i < 4; ++i) TxtR(hd[i], cx0 + cw * (i + 1) - 10, r.y + 72, 12, LANE_COL[i], true);

    uint32_t mq[4] = { max_north_queue, max_east_queue, max_south_queue, max_west_queue };
    uint32_t tc[4] = { total_north_cars, total_east_cars, total_south_cars, total_west_cars };
    uint32_t mt[4] = { time_max_north_queue, time_max_east_queue, time_max_south_queue, time_max_west_queue };
    const char* rowName[3] = { "Max queue", "Total cars", "Max at tick" };
    const uint32_t* rows[3] = { mq, tc, mt };
    for (int rI = 0; rI < 3; ++rI) {
        float y = r.y + 90 + rI * 15.5f;
        Txt(rowName[rI], r.x + 16, y, 12, T.sub);
        for (int i = 0; i < 4; ++i) {
            std::snprintf(b, sizeof b, "%u", rows[rI][i]);
            TxtR(b, cx0 + cw * (i + 1) - 10, y, 12, T.text);
        }
    }
}

static void DrawRightPanel(const Theme& T)
{
    const float x0 = 648, w = 544, cw = (w - 12) / 2.0f;
    DrawBanner(Rectangle{ x0, 8, w, 84 }, T);
    DrawLaneCard(LANE_N, Rectangle{ x0,           104, cw, 98 }, T);
    DrawLaneCard(LANE_E, Rectangle{ x0 + cw + 12, 104, cw, 98 }, T);
    DrawLaneCard(LANE_S, Rectangle{ x0,           214, cw, 98 }, T);
    DrawLaneCard(LANE_W, Rectangle{ x0 + cw + 12, 214, cw, 98 }, T);
    DrawChart(Rectangle{ x0, 324, w, 206 }, T);
    DrawStats(Rectangle{ x0, 542, w, 136 }, T);
}

static void DrawToolbar(const Theme& T)
{
    DrawRectangleRec(Rectangle{ 0, TOOLBAR_Y, (float)WIN_W, (float)WIN_H - TOOLBAR_Y }, T.toolbar);
    DrawLineEx(Vector2{ 0, TOOLBAR_Y }, Vector2{ (float)WIN_W, TOOLBAR_Y }, 1.0f, T.border);

    DrawBtn(BtnPause(), gPaused ? "Resume" : "Pause",
        gPaused ? Color{ 40, 150, 96, 255 } : Color{ 205, 140, 28, 255 },
        gPaused ? Color{ 52, 176, 114, 255 } : Color{ 226, 158, 40, 255 }, WHITE);
    DrawBtn(BtnTick(), "Manual Tick [SPACE]", T.btn, T.btnHover, T.text, 14);

    static const char* SP[3] = { "1x", "2x", "4x" };
    for (int i = 0; i < 3; ++i) {
        bool act = (gSpeedIdx == i);
        DrawBtn(BtnSpeed(i), SP[i], act ? Color{ 52, 120, 246, 255 } : T.btn,
            act ? Color{ 72, 138, 255, 255 } : T.btnHover, act ? WHITE : T.text);
    }

    Rectangle tb = BtnTheme();
    DrawBtn(tb, gNight ? "Night Mode" : "Day Mode", T.btn, T.btnHover, T.text, 14);
    Vector2 ic = { tb.x + 20, tb.y + tb.height * 0.5f };
    if (gNight) {
        DrawCircleV(ic, 7, Color{ 235, 232, 190, 255 });
        DrawCircleV(Vector2{ ic.x + 4, ic.y - 3 }, 6, Hover(tb) ? T.btnHover : T.btn);
    }
    else {
        DrawCircleV(ic, 5, Color{ 245, 170, 20, 255 });
        for (int i = 0; i < 8; ++i) {
            float a = i * 0.785398f;
            DrawLineEx(Vector2{ ic.x + std::cos(a) * 8, ic.y + std::sin(a) * 8 },
                Vector2{ ic.x + std::cos(a) * 11, ic.y + std::sin(a) * 11 }, 2, Color{ 245, 170, 20, 255 });
        }
    }

    Txt("N E S W   add a car       SPACE   tick", 678, 700, 12, T.sub);
    Txt("P   pause      T   theme      ESC   save & exit", 678, 719, 12, T.sub);

    DrawBtn(BtnSave(), "Save & Exit", Color{ 196, 52, 58, 255 }, Color{ 222, 70, 76, 255 }, WHITE);
}

static void HandleInput()
{
    if (IsKeyPressed(KEY_N)) PressLane(LANE_N);
    if (IsKeyPressed(KEY_E)) PressLane(LANE_E);
    if (IsKeyPressed(KEY_S)) PressLane(LANE_S);
    if (IsKeyPressed(KEY_W)) PressLane(LANE_W);
    if (IsKeyPressed(KEY_SPACE)) DoTick();
    if (IsKeyPressed(KEY_P)) gPaused = !gPaused;
    if (IsKeyPressed(KEY_T)) gNight = !gNight;
    if (IsKeyPressed(KEY_ESCAPE)) SaveAndExit();

    for (int i = 0; i < 4; ++i) if (Clicked(BtnAdd(i))) PressLane(i);
    if (Clicked(BtnPause())) gPaused = !gPaused;
    if (Clicked(BtnTick()))  DoTick();
    for (int i = 0; i < 3; ++i) if (Clicked(BtnSpeed(i))) gSpeedIdx = i;
    if (Clicked(BtnTheme())) gNight = !gNight;
    if (Clicked(BtnSave()))  SaveAndExit();
}

int main()
{
    SetConfigFlags(FLAG_MSAA_4X_HINT | FLAG_VSYNC_HINT);
    InitWindow(WIN_W, WIN_H, "Smart Traffic Management System  -  MASM core + Raylib GUI");
    SetExitKey(KEY_NULL);
    SetTargetFPS(60);
    LoadFonts();

    PushHistory();

    while (!gQuit && !WindowShouldClose()) {
        float dt = GetFrameTime();
        float anim = (float)SPEEDS[gSpeedIdx];

        HandleInput();

        if (!gPaused) {
            gAcc += dt * anim;
            int guard = 0;
            while (gAcc >= 1.0f && guard++ < 10) { gAcc -= 1.0f; DoTick(); }
            if (gAcc >= 1.0f) gAcc = 0.0f;
        }
        for (int L = 0; L < 4; ++L) SyncLane(L);
        UpdateVis(dt, anim);
        for (int L = 0; L < 4; ++L) gFlash[L] = std::max(0.0f, gFlash[L] - dt);

        const Theme& T = TH();
        BeginDrawing();
        ClearBackground(T.bg);
        DrawLeftPanel(T);
        DrawRightPanel(T);
        DrawToolbar(T);
        EndDrawing();
    }

    UnloadFonts();
    CloseWindow();
    return 0;
}