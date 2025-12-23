-- Analysis Query #1: Overall Dashboard Summary Statistics
SELECT 
    'Total Registered Cases' as "Metric",
    COUNT(*)::text as "Value"
FROM caregiver
UNION ALL
SELECT 
    'High Risk Cases',
    COUNT(*)::text
FROM preparation a
WHERE (a.serious_flood_zone = 'Y' AND a.mobile_home = 'Y') OR
      (a.serious_flood_zone = 'Y' AND a.clear_route = 'N')
UNION ALL
SELECT 
    'Avg Care Recipient Age',
    ROUND(AVG(b.age), 1)::text
FROM carerecipient b
UNION ALL
SELECT 
    'Ready for Evacuation',
    ROUND(SUM(CASE WHEN a.evacuation_place IS NOT NULL AND a.evacuation_vehicle IS NOT NULL AND a.clear_route = 'Y' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1)::text || '%'
FROM preparation a;

-- Analysis Query #2: Living Conditions Risk Score for GeoMap Visualization
SELECT 
    a.city,
    CASE a.city
        WHEN 'Tampa' THEN 27.9506
        WHEN 'St. Petersburg' THEN 27.7676
        WHEN 'Sarasota' THEN 27.3364
        WHEN 'Clearwater' THEN 27.9659
        WHEN 'Bradenton' THEN 27.4989
        ELSE 27.9506 -- Tampa default
    END as latitude,
    CASE a.city
        WHEN 'Tampa' THEN -82.4572
        WHEN 'St. Petersburg' THEN -82.6403
        WHEN 'Sarasota' THEN -82.5307
        WHEN 'Clearwater' THEN -82.8001
        WHEN 'Bradenton' THEN -82.5748
        ELSE -82.4572  -- Tampa default
    END as longitude,
    COUNT(*) as total_cases,
    ROUND(AVG(
        CASE WHEN b.mobile_home = 'Y' THEN 20 ELSE 0 END +
        CASE WHEN b.serious_flood_zone = 'Y' THEN 30 ELSE CASE WHEN b.flood_zone = 'Y' THEN 15 ELSE 0 END END +
        CASE WHEN b.garage = 'N' THEN 10 ELSE 0 END +
        CASE WHEN b.clear_route = 'N' THEN 15 ELSE 0 END +
        CASE WHEN b.purchased_flight_tickets = 'N' AND b.purchased_bus_tickets = 'N' THEN 20 ELSE 0 END
    ), 1) as avg_risk_score,
    SUM(CASE WHEN b.serious_flood_zone = 'Y' THEN 1 ELSE 0 END) as serious_flood_count,
    SUM(CASE WHEN b.mobile_home = 'Y' THEN 1 ELSE 0 END) as mobile_home_count,
    SUM(CASE WHEN b.serious_flood_zone = 'Y' AND b.mobile_home = 'Y' THEN 1 ELSE 0 END) as critical_risk_count,
    ROUND(AVG(c.age), 1) as avg_care_recipient_age,
    ROUND(AVG(a.age), 1) as avg_caregiver_age
FROM caregiver a
JOIN carerecipient c ON a.caregiver_id = c.caregiver_id
JOIN preparation b ON a.caregiver_id = b.caregiver_id
GROUP BY a.city
ORDER BY avg_risk_score DESC;

-- Analysis Query #3: Living Conditions Risk per City
SELECT 
    a.city,
    COUNT(*) as total_cases,
    SUM(CASE WHEN b.serious_flood_zone = 'Y' THEN 1 ELSE 0 END) as serious_flood_count,
    SUM(CASE WHEN b.mobile_home = 'Y' THEN 1 ELSE 0 END) as mobile_home_count,
    SUM(CASE WHEN b.clear_route = 'N' THEN 1 ELSE 0 END) as no_clear_route_count,
    ROUND(AVG(
        CASE WHEN b.mobile_home = 'Y' THEN 20 ELSE 0 END +
        CASE WHEN b.serious_flood_zone = 'Y' THEN 30 ELSE CASE WHEN b.flood_zone = 'Y' THEN 15 ELSE 0 END END
    ), 1) as avg_risk_score
FROM caregiver a
JOIN preparation b ON a.caregiver_id = b.caregiver_id
GROUP BY a.city
ORDER BY avg_risk_score DESC;

-- Analysis Query #4: High-Risk Households by Flood Risk and Housing Type
SELECT 
    risk_level AS "Flood zone risk",
    home_type AS "Home type",
    case_count AS "Case count"
FROM (
    SELECT 
        CASE 
            WHEN a.serious_flood_zone = 'Y' THEN 'Serious Flood Zone'
            WHEN a.flood_zone = 'Y' THEN 'Flood Zone'
            ELSE 'No Flood Zone'
        END as risk_level,
        CASE WHEN a.mobile_home = 'Y' THEN 'Mobile Home' ELSE 'Regular Home' END as home_type,
        COUNT(*) as case_count
    FROM preparation a
    GROUP BY 
        CASE 
            WHEN a.serious_flood_zone = 'Y' THEN 'Serious Flood Zone'
            WHEN a.flood_zone = 'Y' THEN 'Flood Zone'
            ELSE 'No Flood Zone'
        END,
        CASE WHEN a.mobile_home = 'Y' THEN 'Mobile Home' ELSE 'Regular Home' END
) subquery
ORDER BY 
    CASE risk_level
        WHEN 'Serious Flood Zone' THEN 1
        WHEN 'Flood Zone' THEN 2
        ELSE 3
    END,
    home_type;

-- Analysis Query #5: Estimated Resource Allocation for Shelters per City
SELECT 
    b.city as "City",
    SUM(CASE WHEN a.evacuation_place = 'publicShelter' THEN 1 ELSE 0 END) as "Shelter Capacity",
    SUM(CASE WHEN c.condition_category = 'memory' THEN 1 ELSE 0 END) as "Est. cognitive care specialists",
    SUM(CASE WHEN c.condition_category = 'mobility' THEN 1 ELSE 0 END) as "Mobile Assistance",
    SUM(CASE WHEN c.condition_category = 'respiratory' THEN 1 ELSE 0 END) as "Respiratory Equip units",
    SUM(CASE WHEN c.condition_category = 'cardiac' THEN 1 ELSE 0 END) as "Cardiac monitor. units",
    SUM(CASE WHEN c.condition_category = 'mental_health' THEN 1 ELSE 0 END) as "Est. behavioral support staff",
    SUM(CASE WHEN c.condition_category = 'sensory' THEN 1 ELSE 0 END) as "Sensory Assistance Equip units",
    SUM(CASE WHEN c.condition_category = 'medical_other' THEN 1 ELSE 0 END) as "General medical equipment"
FROM caregiver b
JOIN carerecipient c ON b.caregiver_id = c.caregiver_id
JOIN preparation a ON b.caregiver_id = a.caregiver_id
GROUP BY b.city
HAVING COUNT(*) > 0
ORDER BY b.city DESC;

-- Analysis Query #6: Basic Care Recipients Overview/Information
SELECT 
    CONCAT(first_name, ' ', last_name) AS "Full name", 
    age "Age", gender as "Gender", 
	condition as "Condition", 
    condition_category as "Category", 
	condition_severity as "Severity", 
    special_needs as "Special needs", 
    create_date as "Registration date"
FROM carerecipient;

-- Analysis Query #7: Conditions and Avg Age per Gender
SELECT 
    a.gender,
    COUNT(*) as "Total cases",
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as "Percent. Total",
    SUM(CASE WHEN a.condition_category = 'memory' THEN 1 ELSE 0 END) as "Memory conditions",
    SUM(CASE WHEN a.condition_category = 'mobility' THEN 1 ELSE 0 END) as "Mobility",
    SUM(CASE WHEN a.condition_category = 'respiratory' THEN 1 ELSE 0 END) as "Respiratory",
    SUM(CASE WHEN a.condition_category = 'cardiac' THEN 1 ELSE 0 END) as "Cardiac",
    SUM(CASE WHEN a.condition_category = 'mental_health' THEN 1 ELSE 0 END) as "Mental health condition",
    SUM(CASE WHEN a.condition_category = 'sensory' THEN 1 ELSE 0 END) as "Sensory condition",
    SUM(CASE WHEN a.condition_category = 'medical_other' THEN 1 ELSE 0 END) as "Medical other",
    ROUND(AVG(a.age), 1) as "Avg age"
FROM carerecipient a
JOIN preparation b ON a.caregiver_id = b.caregiver_id
GROUP BY a.gender
ORDER BY "Total cases" DESC;

-- Analysis Query #8: Severity and Age Correlation
    a.age,
    a.condition_category,
    a.condition_severity,
    CASE a.condition_severity 
        WHEN 'low' THEN 1
        WHEN 'moderate' THEN 2
        WHEN 'high' THEN 3
        WHEN 'critical' THEN 4
        ELSE 0
    END as Severity,
    a.condition,
    COUNT(*) as case_count
FROM carerecipient a
JOIN preparation b ON a.caregiver_id = b.caregiver_id
GROUP BY a.age, a.condition_category, a.condition_severity, a.condition
ORDER BY a.age, Severity DESC;

-- Analysis Query #9: Cases per Condition and Severity Levels
SELECT 
    a.condition as "Condition",
    a.condition_category as "Condition category",
    COUNT(*) as "Cases",
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as "Percent. of Total",
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY a.condition_category), 2) as "Percent. within category",
    ROUND(AVG(a.age), 1) as "Avg Age",
    SUM(CASE WHEN a.condition_severity = 'low' THEN 1 ELSE 0 END) as "Low",
    SUM(CASE WHEN a.condition_severity = 'moderate' THEN 1 ELSE 0 END) as "Moderate",
    SUM(CASE WHEN a.condition_severity = 'high' THEN 1 ELSE 0 END) as "High",
    SUM(CASE WHEN a.condition_severity = 'critical' THEN 1 ELSE 0 END) as "Critical"
FROM carerecipient a
GROUP BY "Condition category", a.condition
ORDER BY "Condition category", "Cases" DESC;

-- Analysis Query #10: Care Recipient Condition Severity per City
SELECT 
    a.city,
    COUNT(*) as "total cases",
    SUM(CASE WHEN b.condition_severity = 'critical' THEN 1 ELSE 0 END) as "critical severity",
    SUM(CASE WHEN b.condition_severity = 'high' THEN 1 ELSE 0 END) as "high severity",
    SUM(CASE WHEN b.condition_severity = 'moderate' THEN 1 ELSE 0 END) as "moderate severity",
    SUM(CASE WHEN b.condition_severity = 'low' THEN 1 ELSE 0 END) as "low severity"
FROM caregiver a
JOIN carerecipient b ON a.caregiver_id = b.caregiver_id
GROUP BY a.city
ORDER BY "total cases" DESC;