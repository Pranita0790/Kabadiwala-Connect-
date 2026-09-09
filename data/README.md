\# Kabadiwala Connect — Dataset Structure



This directory contains the datasets used by Kabadiwala Connect.



The datasets are designed according to the SIH problem statement and will be

generated, validated, updated, and used by the application rather than treated

as static data.



\## 1. Material Dataset



Required fields:



\- material\_category

\- sub\_category

\- material\_description

\- image\_reference

\- approximate\_weight

\- condition

\- source\_type

\- estimated\_value



Initial material categories:



\- crt

\- lcd\_panel

\- pcb

\- cable

\- battery

\- motor

\- magnet\_bearing\_assembly

\- mixed\_plastics



\## 2. Price Dataset



Required fields:



\- material\_category

\- location

\- date\_time

\- buying\_price

\- quoted\_price

\- unit

\- recycler\_or\_aggregator

\- historical\_price



\## 3. Recycler Dataset



Required fields:



\- recycler\_id

\- recycler\_name

\- facility\_location

\- materials\_accepted

\- authorization\_details

\- authorization\_status

\- contact\_information

\- offered\_rate

\- pickup\_availability

\- service\_area



\## 4. Transaction Dataset



Required fields:



\- lot\_id

\- collector\_id

\- material\_category

\- quantity\_or\_weight

\- quoted\_price

\- final\_price

\- recycler\_id

\- collection\_location

\- handover\_location

\- date\_time

\- payment\_status

\- transaction\_status



\## 5. Traceability Dataset



Required fields:



\- lot\_id

\- photograph\_reference

\- weight

\- timestamp

\- gps\_location

\- handover\_reference

\- recycler\_confirmation

\- subsequent\_transaction\_status



\## 6. Collector Dataset



Required fields:



\- collector\_id

\- preferred\_language

\- general\_operating\_location

\- transaction\_history

\- earnings\_history



Only minimum information required for the platform should be collected.



\## 7. AI/ML Training Dataset



The AI/ML dataset will support:



\- material classification

\- approximate valuation

\- recycler recommendation

\- transaction anomaly detection



Depending on the model, training/validation data may contain:



\- material images

\- material categories

\- sub-categories

\- approximate weights

\- prices

\- locations

\- transaction records



Each AI/ML dataset must document:



\- source

\- dataset size

\- data quality

\- preprocessing

\- validation method

\- limitations

\- model version



\## Data Lifecycle



The platform should demonstrate:



Collect → Validate → Store → Use → Update → Analyze



Data must be structured so that it can support:



\- data cleaning

\- validation

\- anonymization where required

\- historical analysis

\- price prediction

\- material classification

\- recycler recommendation

\- transaction traceability



\## Initial AI Material Classes



The first MobileNetV2 classifier will use the following categories:



1\. CRT

2\. LCD Panel

3\. PCB

4\. Cable

5\. Battery

6\. Motor

7\. Magnet-bearing Assembly

8\. Mixed Plastics



These classes can be expanded after field research and dataset collection.



\## Important



The initial critical-mineral detector is rule-based and identifies

potential critical-mineral relevance from material categories.



It does not claim to prove elemental composition from an image.



The AI/ML dataset and model versions must be documented as the dataset grows.

