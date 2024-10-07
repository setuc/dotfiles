#!/usr/bin/env python3
import requests
import json
from tabulate import tabulate

def build_pricing_table(json_data, table_data):
    for item in json_data['Items']:
        meter = item['meterName']
        table_data.append([item['armSkuName'], item['retailPrice'], item['unitOfMeasure'], item['armRegionName'], meter, item['productName']])

def select_option(prompt, options):
    print(prompt)
    for i, option in enumerate(options, start=1):
        print(f"{i}. {option}")
    choice = int(input("Enter your choice: "))
    return options[choice - 1]

def main():
    # Define options for the user to choose from
    regions = ['eastus', 'westeurope', 'southeastasia', 'australiaeast']
    sku_series = ['D', 'E', 'NC', 'NV']
    
    # Prompt user to select region and SKU series
    selected_region = select_option("Select a region:", regions)
    selected_series = select_option("Select a VM series:", sku_series)
    
    # Build the query dynamically based on user selections
    query = f"armRegionName eq '{selected_region}' and (contains(skuName, '{selected_series}')) and priceType eq 'Consumption' "
    
    table_data = [['SKU', 'Retail Price', 'Unit of Measure', 'Region', 'Meter', 'Product Name']]
    
    api_url = "https://prices.azure.com/api/retail/prices?api-version=2021-10-01-preview"
    response = requests.get(api_url, params={'$filter': query})
    json_data = json.loads(response.text)
    
    build_pricing_table(json_data, table_data)
    nextPage = json_data.get('NextPageLink', None)
    
    while nextPage:
        response = requests.get(nextPage)
        json_data = json.loads(response.text)
        nextPage = json_data.get('NextPageLink', None)
        build_pricing_table(json_data, table_data)
        
    # Sort the table by retail price (ascending) before displaying
    sorted_table_data = sorted(table_data[1:], key=lambda x: float(x[1]))
    print(tabulate([table_data[0]] + sorted_table_data, headers='firstrow', tablefmt='psql'))

if __name__ == "__main__":
    main()
