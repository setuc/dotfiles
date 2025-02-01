#!/usr/bin/env python3
import requests
import json
from tabulate import tabulate
import sys
import os
import argparse

def build_pricing_table(json_data, table_data):
    for item in json_data.get('Items', []):
        meter = item.get('meterName', '')
        table_data.append([
            item.get('armSkuName', ''),
            item.get('retailPrice', ''),
            item.get('unitOfMeasure', ''),
            item.get('armRegionName', ''),
            meter,
            item.get('productName', '')
        ])

def select_option(prompt, options, default=0):
    """
    Displays a prompt with numbered options. If running in non-interactive mode
    (or in CI), defaults to the specified option.
    """
    print(prompt)
    for i, option in enumerate(options, start=1):
        print(f"{i}. {option}")

    # If non-interactive or CI environment, return the default option.
    if not sys.stdin.isatty() or os.environ.get("CI", "false").lower() == "true":
        print(f"Non-interactive mode detected; defaulting to option {default+1} ({options[default]})")
        return options[default]

    try:
        choice = int(input("Enter your choice: "))
        if 1 <= choice <= len(options):
            return options[choice - 1]
        else:
            print("Invalid choice. Defaulting.")
            return options[default]
    except (EOFError, ValueError):
        print(f"Input error. Defaulting to option {default+1} ({options[default]})")
        return options[default]

def main():
    parser = argparse.ArgumentParser(description="Azure Retail Prices Checker")
    parser.add_argument("--region", type=str, help="Azure region (e.g. eastus)")
    parser.add_argument("--series", type=str, help="VM series (e.g. Standard_D)")
    args = parser.parse_args()

    # Define available options
    regions = ['eastus', 'westeurope', 'southeastasia', 'australiaeast']
    sku_series = ['Standard_D', 'Standard_E', 'Standard_NC', 'Standard_NV']

    # Use provided arguments if valid, else prompt interactively
    if args.region and args.region in regions:
        selected_region = args.region
    else:
        selected_region = select_option("Select a region:", regions)

    if args.series and args.series in sku_series:
        selected_series = args.series
    else:
        selected_series = select_option("Select a VM series:", sku_series)

    # Build the query based on selections
    query = (f"armRegionName eq '{selected_region}' and "
             f"(contains(skuName, '{selected_series}')) and priceType eq 'Consumption'")

    # Create the header row for the table
    table_data = [['SKU', 'Retail Price', 'Unit of Measure', 'Region', 'Meter', 'Product Name']]

    # Set the API URL (with a preview API version, if needed)
    api_url = "https://prices.azure.com/api/retail/prices?api-version=2021-10-01-preview"
    
    response = requests.get(api_url, params={'$filter': query})
    json_data = response.json()

    build_pricing_table(json_data, table_data)
    nextPage = json_data.get('NextPageLink', None)

    # Continue fetching pages, if available
    while nextPage:
        response = requests.get(nextPage)
        json_data = response.json()
        nextPage = json_data.get('NextPageLink', None)
        build_pricing_table(json_data, table_data)

    # Sort the pricing table by retail price (ascending)
    sorted_table_data = sorted(table_data[1:], key=lambda x: float(x[1]))
    print(tabulate([table_data[0]] + sorted_table_data, headers='firstrow', tablefmt='psql'))

if __name__ == "__main__":
    main()
