# A Look Behind Closed Doors...

![STI Pie Chart](https://github.com/user-attachments/assets/8b44f3c0-9b7b-4ad9-abdf-d3b2ab6b108e)

<br><br>


Public Health really has a way of making us-well, the U.S.- look bad. Ever since January 1, 2014, the advent of the Affordable Care Act, sexually trasmitted infections have been on the rise. At first thought, it's quite terrible. 
But on second thought, it becomes clear that more access means a greater amount of illness being reported to entities such as the Center for Disease Control (CDC). Of course, whether good or bad, there must be more to the story. In order to investigate, using machine
learning, webscraping, PDF scraping, and a statistical causal inference mediation model, I wanted to illustrate if the passing of the affordable care act was mediated by any other factors, such as general condom use. Every year since 2003, the Office of Population
Affairs has taken surveys to assess people's "family planning", a.k.a contraception methods around sexual intimacy.

<br>

The project pulls on a number of Python (pdfplumber, tabula-py, pandas) and R (pacman, tidyverse, SuperLearner, rstatix) packages. The end result was a reproducible pipeline that helps to search through pdfs, and build machine learning causal inference workflows,
clean longitudinal dataset, and interpretable ML models — all centered on real-world public health data. I also built a cute in dashboard in Tableau to see how thing progress over time. 
<br>
Keep in mind that from the data, condom use percentages are condom users divided by total active sexual population. Thus, those who practice abstinence were removed.
