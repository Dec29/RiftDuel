"""Check upstream identity, mastery/phase coverage, and duplicate exclusions."""
import csv
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    "PIONEER": {"伊内丝", "伺夜"}, "WARRIOR": {"棘刺", "帕拉斯"},
    "TANK": {"瑕光", "斥罪"}, "SNIPER": {"空弦", "鸿雪"},
    "CASTER": {"卡涅利安", "林"}, "MEDIC": {"焰影苇草", "纯烬艾雅法拉"},
    "SUPPORT": {"灵知", "淬羽赫默"}, "SPECIAL": {"老鲤", "缄默德克萨斯"},
}


def main() -> None:
    files = sorted((ROOT / "import/source_data/six_star").glob("*.json"))
    assert len(files) == 16
    records = [json.loads(path.read_text(encoding="utf-8")) for path in files]
    assert len({item["char_id"] for item in records}) == 16
    assert Counter(item["profession"] for item in records) == dict.fromkeys(EXPECTED, 2)
    current = {row["operator_name"] for row in csv.DictReader((ROOT / "import/operators.csv").open(encoding="utf-8-sig"))}
    # New records may later be imported, but must never overlap the accepted M120 roster.
    accepted = {"风笛", "琴柳", "推进之王", "嵯峨", "德克萨斯", "凛冬", "桃金娘", "焰尾", "极境",
                "煌", "银灰", "斯卡蒂", "陈", "拉普兰德", "幽灵鲨", "赫拉格", "山", "史尔特尔",
                "星熊", "号角", "塞雷娅", "年", "蛇屠箱", "雷蛇", "临光", "古米", "泥岩",
                "能天使", "黑", "提丰", "W", "白金", "蓝毒", "陨星", "杰西卡", "早露",
                "艾雅法拉", "伊芙利特", "莫斯提马", "阿米娅", "天火", "远山", "夜烟", "异客", "刻俄柏",
                "夜莺", "闪灵", "凯尔希", "流明", "白面鸮", "调香师", "赫默", "苏苏洛", "华法琳",
                "安洁莉娜", "铃兰", "麦哲伦", "浊心斯卡蒂", "真理", "初雪", "空", "波登可", "巫恋",
                "琳琅诗怀雅", "傀影", "温蒂", "阿", "砾", "红", "崖心", "水月", "食铁兽"}
    assert len(accepted) == 72 and accepted <= current
    for record in records:
        assert record["name"] in EXPECTED[record["profession"]]
        assert record["name"] not in accepted and record["rarity"] == "TIER_6"
        assert record["commit"] == "17759cc8cdf37388414145d16262a3a06f3ab25e"
        assert len(record["skills"]) == 3 and len(record["talents"]) == 2
        assert record["base"] == record["character"]["phases"][2]["attributesKeyFrames"][-1]["data"]
        assert all(talent["requiredPotentialRank"] == 0 for talent in record["talents"])
        assert all(skill["spData"]["levelUpCost"] is None for skill in record["skills"].values())
    print("PASS: 16 unique six-stars, 8x2 professions, 48 actual M3 records, two actual talents each; M120 72 preserved")


if __name__ == "__main__":
    main()
