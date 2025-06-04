#!/usr/bin/env python3
from __future__ import annotations

import json
from typing import Any, Dict, List

import requests
from tabulate import tabulate


def build_pricing_table(json_data: Dict[str, Any], table_data: List[List[Any]]) -> None:
    for item in json_data["Items"]:
        meter = item["meterName"]
        table_data.append(
            [
                item["armSkuName"],
                item["retailPrice"],
                item["unitOfMeasure"],
                item["armRegionName"],
                meter,
                item["productName"],
            ]
        )


def main() -> None:
    table_data: List[List[Any]] = []
    table_data.append(
        ["SKU", "Retail Price", "Unit of Measure", "Region", "Meter", "Product Name"]
    )

    api_url = "https://prices.azure.com/api/retail/prices"
    query = (
        "armRegionName eq 'southcentralus' and armSkuName eq 'Standard_NP20s' "
        "and priceType eq 'Consumption' and contains(meterName, 'Spot')"
    )
    response = requests.get(api_url, params={"$filter": query})
    json_data = json.loads(response.text)

    build_pricing_table(json_data, table_data)
    next_page = json_data["NextPageLink"]

    while next_page:
        response = requests.get(next_page)
        json_data = json.loads(response.text)
        next_page = json_data.get("NextPageLink")
        build_pricing_table(json_data, table_data)

    print(tabulate(table_data, headers="firstrow", tablefmt="psql"))


if __name__ == "__main__":
    main()
