#!/usr/bin/env python
# coding: utf-8

# In[6]:


# Extract stream tables from family planning annual reports
# Reports from the government Office of Population Affairs
# 2003- 2023


# In[337]:


import tabula.io as t
import pdfplumber
from PyPDF2 import PdfWriter, PdfReader
import os
import time
import re
os.chdir("/Users/kanyin/Documents/Kanyin/Data Science/Data Projects/STI/Other")


# In[37]:


os.listdir() #All pdfs were in a separate folder. Check that no other files except for pdfs


# In[100]:


pdf_list=os.listdir()
pdf_list = [x for x in pdf_list if not x.startswith(".")] #removing hidden files


# In[101]:


search_terms=["Number of female family planning users by primary contraceptive method and age:",
              "Number of male family planning users by primary contraceptive method and age:",
             "Number of female family planning users, by primary contraceptive method and age:",
             "Number of male family planning users, by primary contraceptive method and age: "]


# In[8]:


def search_pages(pdfs, search_terms):
    start_time = time.time()

    """
    Finds pages in a PDF that contain specified search terms and stores them in a global list.

    Parameters:
    - pdf_list (list of str): List of PDF file paths.
    - search_terms (str or list): Keyword(s) to search for (case-insensitive).

    Returns:
     - a dictionary: {pdf_filename: [list of matching_page_numbers]}
    """
    global ref


    if isinstance(search_terms, str):
        search_terms = [search_terms]

    ref={}
    for year in pdfs:
        print(f"Reading page {year}")
        matching_pages=[]
        with pdfplumber.open(year) as pdf:
            for i, page in enumerate(pdf.pages):
                text = page.extract_text()
                if text and any(term.lower() in text.lower() for term in search_terms):
                    matching_pages.append(i + 1)
                    matching_pages=[num for num in matching_pages if num >= 30] #remove table of contents
                    name=f"{year}"
                    ref[name]=matching_pages
        time.sleep(2) # Simulate some work
        end_time = time.time()
        elapsed_time = end_time - start_time
        print(f"Iteration {i+1}: {elapsed_time:.4f} seconds")

    return ref


# In[235]:


search_pages(pdf_list, search_terms)


# In[301]:


all_tables={}
def get_tables(pages):
    start_time = time.time()
    """
    Takes dictionary of matching pages and parses them to return tables.
    """
    for i, pdf in enumerate(ref):

        for input_pdf, matching_pages in ref.items(): #to clean up names 
                input_pdf_lower = input_pdf.lower()
                has_fpar = "fpar" in input_pdf_lower
                year_match = re.search(r'20\d{2}', input_pdf_lower)

                if has_fpar and year_match:
                    year = year_match.group()
                    name = f"fpar-{year}"


                for i, number in enumerate(matching_pages):
                    print(f"Reading page {number} from '{input_pdf}'...")

                    table = t.read_pdf(
                        input_pdf,
                        pages=number,
                        multiple_tables=True,
                        stream=True,
                        output_format="dataframe",
                        guess=True
                    )

                    key= f"{name}_page{number}_table{i+1}"
                    all_tables[key] = table
                    time.sleep(2) 

                    print(f"Completed reading page {number} from '{name}'. Found {len(tables)} tables.")
                    end_time = time.time()
                    elapsed_time = end_time - start_time
                    print(f"Time lapsed: {elapsed_time:.4f} seconds")

        return all_tables



# In[348]:


get_tables(ref)


# In[351]:


# Save the list of DataFrames using pickle
import pandas as pd
import pickle
with open('list_of_dataframes.pkl', 'wb') as f:
    pickle.dump(all_tables, f)


# In[352]:


with open('list_of_dataframes.pkl', 'rb') as f:
    loaded_list_of_dfs = pickle.load(f)


# In[353]:


loaded_list_of_dfs


# In[360]:


import re
import pandas as pd

rates = {}
redo = {}

def crude_rates(list_tables):
    for i, (string, dataset) in enumerate(list_tables.items(), start=1):
        table = dataset[0].copy()
        print(table)

        answer = input("Continue? (y/n): ") #optional step to look at the table to make pdf sure the scrape was successful
        if answer.lower() == 'n':
            redo[i] = string
            continue

        name = f'{string}'
        sex = 'Female' if 'table1' in name.lower() else 'Male'
        year_match = re.search(r'20\d{2}', string)
        year = year_match.group() if year_match else 'unknown'
        updated_name = f'fpar-{year}-{sex}'

        # Set index to first column
        table.set_index(table.columns[0], inplace=True)
        table.index = table.index.astype(str)
        firstcol = table.columns[0]

        # Get index labels
        try:
            Male = table.index[table.index.str.match('Male condom', case=False)][0]
            Abs = table.index[table.index.str.contains('Abstin', case=False)][0]
            Tot = table.index[table.index.str.contains('Total', case=False)][0]
        except IndexError:
            print(f" Missing required row (Male/Abstinence/Total) in: {string}")
            redo[i] = string
            continue

        # Female condom is optional
        Fem_index = table.index[table.index.str.match('Female condom', case=False)]
        Fem = Fem_index[0] if not Fem_index.empty else None

        # Helper function to clean and convert value
        def get_int_value(index_label):
            val = table.loc[index_label, firstcol]
            if isinstance(val, pd.Series):
                val = val.iloc[0]
            return int(str(val).replace(',', '').strip())

        try:
            fem_value = get_int_value(Fem) if Fem else 0
            male_value = get_int_value(Male)
            abst_value = get_int_value(Abs)
            total_value = get_int_value(Tot)
        except Exception as e:
            print(f" Value conversion failed in {string}: {e}")
            redo[i] = string
            continue

        # Compute results
        cndm_value = male_value if string.endswith('2') else male_value + fem_value
        activ_value = total_value - abst_value
        crude_rate = cndm_value / activ_value * 100000 if activ_value > 0 else 0

        result = {
            'condom_users': cndm_value,
            'active_population': activ_value,
            'crude_rate': crude_rate
        }

        rates[updated_name] = result
        print(f" {updated_name}: {result}")

    return rates


# In[361]:


crude_rates(all_tables)


# In[371]:


os.getcwd()


# In[372]:


rates_table=pd.DataFrame(rates).transpose().sort_index()
rates_table.to_csv("/Users/kanyin/Documents/Kanyin/Data Science/Data Projects/STI/Data/STI_Protection.csv")

