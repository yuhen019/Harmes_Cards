# -*- coding: utf-8 -*-
"""生成 Hermes Cards 导入 CSV（P1 核心语块 第二批：小米之家销售场景 100 张）"""
import csv, io, sys, os

ROWS = []

def add(front, back, context, source, tag):
    ROWS.append(dict(front=front, back=back, context=context,
                     source=source, tag=tag, type="speaking", flipped="0"))

S1 = "小米之家 · 迎宾开场 Day2"
S2 = "小米之家 · 需求挖掘 Day2"
S3 = "小米之家 · 产品讲解 v2"
S4 = "小米之家 · 生态链产品 v2"
S5 = "小米之家 · 演示与体验 v2"
S6 = "小米之家 · 价格与促销 v2"
S7 = "小米之家 · 竞品对比 v2"
S8 = "小米之家 · 库存与调货 v2"
S9 = "小米之家 · 售后与保修 v2"
S10 = "小米之家 · 支付与开票 v2"
S11 = "小米之家 · 异议处理 v2"
S12 = "小米之家 · 送客与复购 v2"

# ===== 1. 迎宾开场（8）=====
add("顾客在门口张望，主动请进来", "Come on in — we're open.",
    "（顾客在门口犹豫）Come on in, we're open. Take a look around.", S1, "迎宾开场")
add("请顾客慢慢看，不催单", "Take your time — no rush.",
    "Take your time, no rush. I'll be right here if you need me.", S1, "迎宾开场")
add("顾客说只是随便看看，别走开", "No problem — I'll be right here.",
    "A: Just looking, thanks. — B: No problem, I'll be right here.", S1, "迎宾开场")
add("问顾客是来旅游还是常住", "Are you visiting, or do you live here?",
    "Are you visiting Suzhou, or do you live here?", S1, "迎宾开场")
add("问顾客今天想看点什么", "What can I help you with today?",
    "Good morning! What can I help you with today?", S1, "迎宾开场")
add("忙不过来，请顾客稍等一下", "I'll be with you in a minute.",
    "（手上还有客人）I'll be with you in a minute, sorry.", S1, "迎宾开场")
add("招呼顾客坐下慢慢聊", "Have a seat — I'll bring it over.",
    "Have a seat over here, I'll bring the phone over.", S1, "迎宾开场")
add("说明店里可以随便试用", "Feel free to try anything on display.",
    "Feel free to try anything on display — nothing is locked.", S1, "迎宾开场")

# ===== 2. 需求挖掘（9）=====
add("问顾客现在用的是什么手机", "What are you using right now?",
    "What are you using right now — an iPhone or an Android?", S2, "需求挖掘")
add("问顾客手机主要拿来干什么", "What do you use your phone for most?",
    "What do you use your phone for most — work, photos, games?", S2, "需求挖掘")
add("问顾客最在意哪一点", "What matters most to you — camera or battery?",
    "What matters most to you — the camera, the battery, or the price?", S2, "需求挖掘")
add("礼貌地问预算范围", "Do you have a budget in mind?",
    "Do you have a budget in mind, so I can show you the right ones?", S2, "需求挖掘")
add("问顾客平时拍照多不多", "Do you take a lot of photos?",
    "Do you take a lot of photos? Then the camera matters more.", S2, "需求挖掘")
add("问顾客打不打游戏", "Do you play games on your phone?",
    "Do you play games on your phone? This one handles them easily.", S2, "需求挖掘")
add("问顾客需不需要双卡", "Do you need two SIM cards?",
    "Do you need two SIM cards, or is one enough?", S2, "需求挖掘")
add("问顾客这部手机用了多久", "How long have you had this phone?",
    "How long have you had this phone — three years?", S2, "需求挖掘")
add("把顾客的需求复述一遍确认", "So you want a big screen and long battery.",
    "So you want a big screen, a long battery, and under 3,000. Right?", S2, "需求挖掘")

# ===== 3. 手机产品讲解（12）=====
add("说明屏幕大小和材质", "It has a 6.7-inch AMOLED screen.",
    "It has a 6.7-inch AMOLED screen — very bright outdoors.", S3, "产品讲解")
add("说明屏幕刷新率", "The screen refreshes at 120 hertz.",
    "The screen refreshes at 120 hertz, so scrolling looks smooth.", S3, "产品讲解")
add("说明处理器性能", "It runs on the latest Snapdragon chip.",
    "It runs on the latest Snapdragon chip — no lag at all.", S3, "产品讲解")
add("说明充电速度", "It charges to full in about 30 minutes.",
    "It charges to full in about 30 minutes with the 90-watt charger.", S3, "产品讲解")
add("说明支持无线充电", "It also supports wireless charging.",
    "It also supports wireless charging — just put it on the pad.", S3, "产品讲解")
add("说明主摄像素", "The main camera is 200 megapixels.",
    "The main camera is 200 megapixels, with optical stabilization.", S3, "产品讲解")
add("说明夜景拍照好", "It takes great photos at night.",
    "It takes great photos at night — no blur, no yellow light.", S3, "产品讲解")
add("说明机身轻薄", "It's thin and light — only 180 grams.",
    "It's thin and light, only 180 grams, so your hand won't get tired.", S3, "产品讲解")
add("说明防水等级", "It's water-resistant to IP68.",
    "It's water-resistant to IP68 — rain and splashes are fine.", S3, "产品讲解")
add("说明存储版本", "This one comes with 256 gigs.",
    "This one comes with 256 gigs of storage — plenty for photos.", S3, "产品讲解")
add("说明系统更新年限", "You get four years of system updates.",
    "You get four years of system updates, so it stays fast.", S3, "产品讲解")
add("说明这是今年的新款", "This is this year's new model.",
    "This is this year's new model — it came out in September.", S3, "产品讲解")

# ===== 4. 生态链产品（10）=====
add("介绍手环能测睡眠和心率", "This band tracks your sleep and heart rate.",
    "This band tracks your sleep and heart rate — it lasts two weeks.", S4, "生态链")
add("介绍扫地机器人能扫能拖", "It vacuums and mops by itself.",
    "It vacuums and mops by itself — you just empty the tank.", S4, "生态链")
add("介绍空气净化器适用面积", "It cleans the air in a big room.",
    "It cleans the air in a big room — up to 60 square meters.", S4, "生态链")
add("介绍电视尺寸和分辨率", "This TV has a 65-inch 4K screen.",
    "This TV has a 65-inch 4K screen — great for movies.", S4, "生态链")
add("介绍笔记本轻薄续航", "It's light, and the battery lasts all day.",
    "It's light, and the battery lasts all day — good for travel.", S4, "生态链")
add("介绍充电宝能给手机充几次", "It charges your phone three times over.",
    "It charges your phone three times over — 20,000 mAh.", S4, "生态链")
add("介绍耳机降噪", "These earbuds cancel noise on the train.",
    "These earbuds cancel noise on the train — very good for commuting.", S4, "生态链")
add("介绍音箱能语音控制家电", "You can control the lights with your voice.",
    "You can control the lights and the AC with your voice.", S4, "生态链")
add("介绍滑板车续航", "It goes 30 kilometers on one charge.",
    "It goes 30 kilometers on one charge — enough for a commute.", S4, "生态链")
add("说明产品都能连同一个 App", "They all work together in one app.",
    "They all work together in one app — one tap to set them up.", S4, "生态链")

# ===== 5. 演示与体验（10）=====
add("请顾客自己上手试", "Here, try it yourself.",
    "Here, try it yourself — unlock it and open the camera.", S5, "演示体验")
add("引导顾客拍一张试试", "Take a photo of that shelf over there.",
    "Take a photo of that shelf over there — look at the detail.", S5, "演示体验")
add("演示快充已经充了不少", "Watch — it's already at 40 percent.",
    "Watch, it's already at 40 percent — that was two minutes.", S5, "演示体验")
add("让顾客滑动感受流畅度", "Scroll up and down — see how smooth it is?",
    "Scroll up and down — see how smooth it is at 120 hertz?", S5, "演示体验")
add("演示语音助手", "Ask it to play some music.",
    "Ask it to play some music — it understands English.", S5, "演示体验")
add("让顾客两只手各拿一款对比", "Hold them both — which feels better?",
    "Hold them both — which one feels better in your hand?", S5, "演示体验")
add("演示投屏到电视", "Let me show you how mirroring works.",
    "Let me show you how mirroring works — one tap, that's it.", S5, "演示体验")
add("演示手环配对数秒完成", "It pairs with your phone in ten seconds.",
    "It pairs with your phone in ten seconds — I'll do it now.", S5, "演示体验")
add("让顾客戴上耳机感受降噪", "Put them on — the noise just disappears.",
    "Put them on — the noise just disappears. Hear that?", S5, "演示体验")
add("让顾客试打电话听筒效果", "Try a call — the speaker is on the front.",
    "Try a call — the speaker is on the front, so it's loud.", S5, "演示体验")

# ===== 6. 价格与促销（10）=====
add("说明本月的优惠活动", "There's a discount until the end of the month.",
    "There's a discount until the end of the month — 300 off.", S6, "价格促销")
add("说明送什么赠品", "You get a case and a charger for free.",
    "You get a case and a charger for free with this one.", S6, "价格促销")
add("说明支持以旧换新", "We take trade-ins — bring your old phone.",
    "We take trade-ins — bring your old phone and we'll value it.", S6, "价格促销")
add("说明学生有额外折扣", "Students get another five percent off.",
    "Students get another five percent off — just show your card.", S6, "价格促销")
add("说明可以免息分期", "You can pay in twelve installments, no interest.",
    "You can pay in twelve installments, no interest at all.", S6, "价格促销")
add("说明线上线下同价", "The price is the same online and in store.",
    "The price is the same online and in store — no need to compare.", S6, "价格促销")
add("说明降价可以补差价", "If the price drops in seven days, we refund.",
    "If the price drops in seven days, we refund the difference.", S6, "价格促销")
add("说明套装更划算", "The bundle saves you about 300 yuan.",
    "The bundle — phone plus watch — saves you about 300 yuan.", S6, "价格促销")
add("说明会员价更低", "Members get a lower price on accessories.",
    "Members get a lower price on accessories — it's free to join.", S6, "价格促销")
add("顾客嫌贵时解释贵在哪", "The price is mostly the camera and the screen.",
    "The price is mostly the camera and the screen — both are top-end.", S6, "价格促销")

# ===== 7. 竞品对比（8）=====
add("顾客提苹果，客观比较", "iPhone wins on video; this one wins on battery.",
    "A: Why not an iPhone? — B: iPhone wins on video, this wins on battery.", S7, "竞品对比")
add("顾客说华为更好", "Both are good — this one costs less.",
    "A: Huawei is better. — B: Both are good, but this one costs less.", S7, "竞品对比")
add("顾客说网上买更便宜", "Online is cheaper, but you get no service here.",
    "Online is cheaper, but you get no service here — no setup, no repair.", S7, "竞品对比")
add("说明和低配版的差别", "This one has a better camera than the Lite.",
    "This one has a better camera and a faster chip than the Lite.", S7, "竞品对比")
add("顾客怀疑是不是杂牌", "No, this is Xiaomi's own brand.",
    "A: Is this a copy? — B: No, this is Xiaomi's own brand.", S7, "竞品对比")
add("顾客问售后网点多不多", "There are service centers in most big cities.",
    "There are service centers in most big cities — and one here.", S7, "竞品对比")
add("顾客问系统好不好用", "It's Android-based, and quite clean.",
    "It's Android-based, and quite clean — no extra ads.", S7, "竞品对比")
add("顾客问这个价位值不值", "For this price, I'd say it's hard to beat.",
    "For this price, I'd say it's hard to beat — nothing comes close.", S7, "竞品对比")

# ===== 8. 库存与调货（7）=====
add("查库存，请稍等", "Let me check the system for you.",
    "Let me check the system for you — one second.", S8, "库存调货")
add("这个颜色暂时没货", "We're out of that color right now.",
    "We're out of that color right now — black is still available.", S8, "库存调货")
add("说明什么时候到货", "It should be back in stock on Friday.",
    "It should be back in stock on Friday — I can hold one for you.", S8, "库存调货")
add("可以从别的店调货", "I can transfer one from another store.",
    "I can transfer one from another store — it takes a day.", S8, "库存调货")
add("请顾客留电话等通知", "Leave your number and I'll call you.",
    "Leave your number and I'll call you the moment it arrives.", S8, "库存调货")
add("预订需要付定金", "It's a 200-yuan deposit to reserve one.",
    "It's a 200-yuan deposit to reserve one — the rest on pickup.", S8, "库存调货")
add("只剩展示机了", "We only have the display unit left.",
    "We only have the display unit left — I can take 10% off.", S8, "库存调货")

# ===== 9. 售后与保修（8）=====
add("说明保修时长", "One year for the phone, two for the battery.",
    "One year for the phone, two for the battery — free repairs.", S9, "售后保修")
add("说明人为损坏不在保修内", "Drop damage isn't covered by the warranty.",
    "Drop damage isn't covered by the warranty, but we can still fix it.", S9, "售后保修")
add("说明七天无理由退货", "You can return it within seven days, no questions.",
    "You can return it within seven days, no questions asked.", S9, "售后保修")
add("说明维修要带什么", "Bring the receipt and the phone itself.",
    "Bring the receipt and the phone itself — that's all we need.", S9, "售后保修")
add("说明维修要多久", "It usually takes three to five days.",
    "It usually takes three to five days — we'll text you.", S9, "售后保修")
add("说明维修期间可借备用机", "We can lend you a loaner while it's repaired.",
    "We can lend you a loaner while it's repaired — free of charge.", S9, "售后保修")
add("说明店里可以贴膜", "We do screen protectors here for 50 yuan.",
    "We do screen protectors here for 50 yuan — takes five minutes.", S9, "售后保修")
add("说明可以免费帮你导数据", "We'll move your data over for free.",
    "We'll move your data over for free — photos, contacts, WeChat.", S9, "售后保修")

# ===== 10. 支付与开票（8）=====
add("说明支持国际信用卡", "Yes, we take Visa and Mastercard.",
    "A: Can I pay by card? — B: Yes, we take Visa and Mastercard.", S10, "支付开票")
add("说明不收外币现金", "Sorry, we only take Chinese yuan.",
    "Sorry, we only take Chinese yuan — there's an ATM downstairs.", S10, "支付开票")
add("外卡支付需要护照", "For foreign cards, I'll need your passport.",
    "For foreign cards, I'll need your passport — it's the rule.", S10, "支付开票")
add("问顾客要不要退税发票", "Do you need a receipt for tax refund?",
    "Do you need a receipt for the tax refund at the airport?", S10, "支付开票")
add("说明帮你填退税单", "I'll fill in the tax refund form for you.",
    "I'll fill in the tax refund form for you — just sign here.", S10, "支付开票")
add("说明开票需要什么信息", "I just need your name and passport number.",
    "I just need your name and passport number for the invoice.", S10, "支付开票")
add("确认支付成功", "It went through — here's your receipt.",
    "It went through — here's your receipt and your warranty card.", S10, "支付开票")
add("说明发票可以发邮箱", "I can email the invoice to you.",
    "I can email the invoice to you — what's your address?", S10, "支付开票")

# ===== 11. 异议处理（6）=====
add("顾客说要再考虑一下", "Of course — take your time.",
    "A: I'll think about it. — B: Of course, take your time.", S11, "异议处理")
add("顾客砍价，用赠品兜住", "Price is fixed, but I can add a gift.",
    "A: Any discount? — B: Price is fixed, but I can add a gift.", S11, "异议处理")
add("顾客抱怨排队太久", "Sorry for the wait — I'll be quick.",
    "Sorry for the wait — I'll be quick, just one more step.", S11, "异议处理")
add("顾客说上次买的出问题了", "I'm sorry about that — let me fix it now.",
    "I'm sorry about that — let me check it and fix it now.", S11, "异议处理")
add("顾客情绪激动，先安抚再查", "I understand — let me sort this out.",
    "I understand why you're upset — let me sort this out.", S11, "异议处理")
add("顾客要投诉或找店长", "Let me call my manager for you.",
    "Let me call my manager for you — she'll be here in two minutes.", S11, "异议处理")

# ===== 12. 送客与复购（4）=====
add("送客并邀请下次再来", "Thanks for stopping by — see you next time.",
    "Thanks for stopping by — see you next time!", S12, "送客复购")
add("加微信方便售后联系", "Add me on WeChat if you have questions.",
    "Add me on WeChat if you have any questions later.", S12, "送客复购")
add("说明有问题随时回来", "Come back anytime if anything comes up.",
    "Come back anytime if anything comes up — no appointment needed.", S12, "送客复购")
add("请顾客推荐给朋友", "If you like it, tell your friends about us.",
    "If you like it, tell your friends about us — we have referral gifts.", S12, "送客复购")

OUT = r"D:\1.software\Workspace\WorkBuddy\AI_Coding_Tools\imports\P1-核心语块-第二批_HermesCards.csv"
if len(sys.argv) > 1:
    OUT = sys.argv[1]

FIELDS = ["front", "back", "context", "source", "tag", "type", "flipped"]
with open(OUT, "w", encoding="utf-8-sig", newline="") as f:
    w = csv.DictWriter(f, fieldnames=FIELDS, quoting=csv.QUOTE_MINIMAL)
    w.writeheader()
    w.writerows(ROWS)

# ---- 自检 ----
errs = []
for i, r in enumerate(ROWS, start=1):
    wc = len(r["back"].replace("—", " ").split())
    if wc > 9:
        errs.append(f"第{i}张 back 超过9词({wc}): {r['back']}")
    if not r["front"] or not r["back"] or not r["context"]:
        errs.append(f"第{i}张 有空字段")
    if len(r["front"]) < 4:
        errs.append(f"第{i}张 front 过短")

print(f"生成卡片数: {len(ROWS)}")
print(f"输出: {OUT}")
print("按 tag:", {t: sum(1 for r in ROWS if r['tag'] == t) for t in dict.fromkeys(r['tag'] for r in ROWS)})
print("自检问题数:", len(errs))
for e in errs:
    print("  !", e)
