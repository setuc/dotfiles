import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1] / "bin"))

from checkPrices2 import build_pricing_table


def test_build_pricing_table():
    sample = {
        "Items": [
            {
                "armSkuName": "Standard_DS1_v2",
                "retailPrice": 0.1,
                "unitOfMeasure": "1 Hour",
                "armRegionName": "eastus",
                "meterName": "Compute Hours",
                "productName": "Virtual Machines",
            }
        ]
    }
    table: list[list[str]] = []
    build_pricing_table(sample, table)
    assert table[0][0] == "Standard_DS1_v2"
    assert table[0][1] == 0.1
