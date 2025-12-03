/* 
==========================================
PROJECT: HR Employee Analytics in SQL
Dataset: HR Employee Attrition (Kaggle)
Author: Aleksandra Dybka
Description:
A full SQL analytics project including:
1. Data model creation
2. Income segmentation (CASE)
3. Department-level aggregation
4. Pattern-matching role analysis (UNION ALL)
5. Salary metrics report (MIN / MAX / AVG)
6. Salary projection using RECURSIVE CTE
7. Business logic triggers:
   - Attrition logging
   - Salary change logging
==========================================
*/

-- ======================================
-- 1. CREATE TABLE
-- ======================================

CREATE TABLE employees (
    Age INT,
    Attrition VARCHAR(10),
    BusinessTravel VARCHAR(50),
    DailyRate INT,
    Department VARCHAR(100),
    DistanceFromHome INT,
    Education INT,
    EducationField VARCHAR(100),
    EmployeeCount INT,
    EmployeeNumber INT PRIMARY KEY,
    EnvironmentSatisfaction INT,
    Gender VARCHAR(10),
    HourlyRate INT,
    JobInvolvement INT,
    JobLevel INT,
    JobRole VARCHAR(100),
    JobSatisfaction INT,
    MaritalStatus VARCHAR(20),
    MonthlyIncome INT,
    MonthlyRate INT,
    NumCompaniesWorked INT,
    Over18 VARCHAR(5),
    OverTime VARCHAR(5),
    PercentSalaryHike INT,
    PerformanceRating INT,
    RelationshipSatisfaction INT,
    StandardHours INT,
    StockOptionLevel INT,
    TotalWorkingYears INT,
    TrainingTimesLastYear INT,
    WorkLifeBalance INT,
    YearsAtCompany INT,
    YearsInCurrentRole INT,
    YearsSinceLastPromotion INT,
    YearsWithCurrManager INT
);

-- ======================================
-- 2. DATA PREVIEW
-- ======================================
SELECT * FROM employees LIMIT 6;

-- ======================================
-- 3. CLASSIFY EMPLOYEES BY INCOME LEVEL
-- ======================================

SELECT 
    EmployeeNumber,
    MonthlyIncome,
    CASE 
        WHEN MonthlyIncome <= 3000 THEN 'Low income'
        WHEN MonthlyIncome BETWEEN 3000 AND 8000 THEN 'Middle income'
        ELSE 'High income'
    END AS IncomeGroup
FROM employees
ORDER BY MonthlyIncome;

-- ======================================
-- 4. INCOME GROUPS PER DEPARTMENT
-- ======================================

SELECT 
    Department,
    CASE 
        WHEN MonthlyIncome < 3000 THEN 'Low income'
        WHEN MonthlyIncome BETWEEN 3000 AND 8000 THEN 'Middle income'
        ELSE 'High income'
    END AS IncomeGroup,
    COUNT(*) AS EmployeeCount
FROM employees
GROUP BY Department, IncomeGroup
ORDER BY Department, IncomeGroup;

-- ======================================
-- 5. COUNT MANAGERIAL & TECHNICAL ROLES
-- Managerial → contains "Manager"
-- Technical/HR → contains "Human"
-- ======================================

SELECT 
    COUNT(*) AS total_type
FROM employees 
WHERE JobRole LIKE '%Manager%'

UNION ALL

SELECT 
    COUNT(*) AS total_type
FROM employees 
WHERE JobRole LIKE '%Human%';

-- ======================================
-- 6. SALARY METRICS REPORT (MIN / MAX / AVG)
-- ======================================

SELECT 
    'min_income' AS metric,
    MIN(MonthlyIncome) AS value
FROM employees

UNION ALL

SELECT 
    'max_income' AS metric,
    MAX(MonthlyIncome) AS value
FROM employees

UNION ALL

SELECT 
    'avg_income' AS metric,
    AVG(MonthlyIncome) AS value
FROM employees;

-- ======================================
-- 7. SALARY PROJECTION USING RECURSIVE CTE
-- Projecting income for next 10 years @ 5% yearly increase
-- ======================================

WITH RECURSIVE salary_projection AS (
    SELECT 
        EmployeeNumber,
        MonthlyIncome AS current_salary,
        0 AS year
    FROM employees

    UNION ALL

    SELECT 
        EmployeeNumber,
        current_salary * 1.05,
        year + 1
    FROM salary_projection
    WHERE year < 10
)
SELECT * FROM salary_projection;

-- ======================================
-- 8. TRIGGER: LOG ATTRITION EVENTS
-- Logs employees leaving the company
-- ======================================

CREATE TABLE attrition_log (
    EmployeeNumber INT,
    LeaveDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DELIMITER $$

CREATE TRIGGER log_attrition 
AFTER UPDATE ON employees 
FOR EACH ROW 
BEGIN
    IF OLD.Attrition = 'No' AND NEW.Attrition = 'Yes' THEN 
        INSERT INTO attrition_log (EmployeeNumber)
        VALUES (NEW.EmployeeNumber);
    END IF;
END $$

DELIMITER ;

-- TEST:
-- UPDATE employees SET Attrition = 'Yes' WHERE EmployeeNumber = 7;
-- SELECT * FROM attrition_log;

-- ======================================
-- 9. TRIGGER: LOG SALARY CHANGES
-- Stores old and new salary after every update
-- ======================================

CREATE TABLE salary_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    EmployeeNumber INT,
    old_income INT,
    new_income INT,
    change_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DELIMITER $$

CREATE TRIGGER log_salary 
AFTER UPDATE ON employees
FOR EACH ROW
BEGIN
    IF OLD.MonthlyIncome <> NEW.MonthlyIncome THEN 
        INSERT INTO salary_log (EmployeeNumber, old_income, new_income)
        VALUES (NEW.EmployeeNumber, OLD.MonthlyIncome, NEW.MonthlyIncome);
    END IF;
END $$

DELIMITER ;

-- TEST:
-- UPDATE employees SET MonthlyIncome = 6000 WHERE EmployeeNumber = 1;
-- SELECT * FROM salary_log;

