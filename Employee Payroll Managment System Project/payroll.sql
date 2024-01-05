-- Create a table to store departments
CREATE TABLE departments (
    department_id serial PRIMARY KEY,
    department_name VARCHAR(100));
-- Create a table to store employee information
CREATE TABLE employees (
    employee_id serial PRIMARY KEY,
    first_name VARCHAR(50),
	middle_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    hire_date DATE,
    salary DECIMAL(10, 2),
	department_id INT,
	foreign key(department_id) REFERENCES departments(department_id));

-- Create a table to store payroll information
CREATE TABLE payroll (
    payroll_id serial PRIMARY KEY,
    employee_id INT ,
    pay_date DATE,
    hours_worked DECIMAL(5, 2),
    gross_salary DECIMAL(10, 2),
    deductions DECIMAL(10, 2),
    net_salary DECIMAL(10, 2),
	foreign key(employee_id) REFERENCES employees(employee_id)
);

-- Create a table to store attendance information
CREATE TABLE attendance (
    attendance_id serial PRIMARY KEY,
    employee_id INT ,
    attendance_date DATE,
    hours_worked DECIMAL(5, 2),
	foreign key(employee_id) REFERENCES employees(employee_id)
);
-- Create a table to store leave information
CREATE TABLE leave (
    leave_id serial PRIMARY KEY,
    employee_id INT,
    leave_date DATE,
    leave_type VARCHAR(50),
    duration INT,
	foreign key(employee_id) REFERENCES employees(employee_id)
);
-- Insert some department data
INSERT INTO departments (department_name) VALUES
    ('HR'),
    ('Finance'),
    ('Engineering'),
	('Sales');

-- Inserting an employee's payroll information
INSERT INTO employees (first_name, last_name, email, hire_date, salary)
VALUES ('John', 'Doe', 'john.doe@example.com', '2023-01-15', 50000);

-- Inserting payroll information
INSERT INTO payroll (employee_id, pay_date, hours_worked)
VALUES (1, '2023-10-01', 160);

-- Example: Assign employees to departments
UPDATE employees SET department_id = 1 WHERE employee_id = 1; -- John Doe in HR
UPDATE employees SET department_id = 2 WHERE employee_id = 2; -- Jane Smith in Finance

-- Inserting more employees
INSERT INTO employees (first_name, last_name, email, hire_date, salary, department_id)
VALUES('John', 'Doe', 'john.doe@example.com', '2023-01-15', 50000,3),
    ('Alice', 'Johnson', 'alice.j@example.com', '2023-02-20', 55000, 3), -- Alice Johnson in Engineering
    ('Bob', 'Williams', 'bob.w@example.com', '2023-03-15', 60000, 3);

-- Inserting payroll information with the trigger
INSERT INTO payroll (employee_id, pay_date, hours_worked)
VALUES (3, '2023-10-01', 160); -- Alice's payroll
INSERT INTO payroll (employee_id, pay_date, hours_worked)
VALUES (4, '2023-10-01', 168); -- Bob's payroll

-- Function to calculate the gross salary
CREATE OR REPLACE FUNCTION calculate_gross_salary(hours_worked DECIMAL, hourly_rate DECIMAL)
RETURNS DECIMAL AS $$
BEGIN
    RETURN hours_worked * hourly_rate;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate deductions (e.g., taxes, insurance)
CREATE OR REPLACE FUNCTION calculate_deductions(gross_salary DECIMAL)
RETURNS DECIMAL AS $$
BEGIN
    RETURN gross_salary * 0.2; -- Assuming 20% deductions
END;
$$ LANGUAGE plpgsql;

-- Function to calculate net salary
CREATE OR REPLACE FUNCTION calculate_net_salary(gross_salary DECIMAL, deductions DECIMAL)
RETURNS DECIMAL AS $$
BEGIN
    RETURN gross_salary - deductions;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically calculate and update payroll information
CREATE OR REPLACE FUNCTION update_payroll()
RETURNS TRIGGER AS $$
BEGIN
    NEW.gross_salary := calculate_gross_salary(NEW.hours_worked, 10.0); -- Assuming hourly rate is $10
    NEW.deductions := calculate_deductions(NEW.gross_salary);
    NEW.net_salary := calculate_net_salary(NEW.gross_salary, NEW.deductions);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER payroll_update_trigger
BEFORE INSERT ON payroll
FOR EACH ROW
EXECUTE FUNCTION update_payroll();

-- The trigger will automatically calculate gross salary, deductions, and net salary.
-- You can retrieve this information using SELECT queries.

-- SELECT query to retrieve employee and payroll information along with department
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    e.email,
    e.hire_date,
    e.salary,
    d.department_name,
    p.pay_date,
    p.hours_worked,
    p.gross_salary,
    p.deductions,
    p.net_salary
FROM employees e
JOIN departments d ON e.department_id = d.department_id
JOIN payroll p ON e.employee_id = p.employee_id;

-- This query will retrieve data from all three tables and display it in a tabular format.
-- Example: Update the salary of an employee (e.g., increasing John Doe's salary to $55000)
UPDATE employees
SET salary = 55000
WHERE employee_id = 1; -- Assuming employee_id 1 corresponds to John Doe
-- Example: Delete an employee and their payroll information (e.g., deleting Alice Johnson)
DELETE FROM payroll
WHERE employee_id = 3; -- Delete Alice's payroll information

DELETE FROM employees
WHERE employee_id = 3; -- Delete Alice's employee record
-- Example: Calculate total expenses (salaries) for each department
SELECT
    d.department_id,
    d.department_name,
    SUM(e.salary) AS total_expenses
FROM departments d
LEFT JOIN employees e ON d.department_id = e.department_id
GROUP BY d.department_id, d.department_name;


-- Insert some leave and attendance data (example)
INSERT INTO leave (employee_id, leave_date, leave_type, duration)
VALUES
    (1, '2023-10-05', 'Vacation', 5),
    (2, '2023-10-10', 'Sick Leave', 2);

INSERT INTO attendance (employee_id, attendance_date, hours_worked)
VALUES
    (1, '2023-10-01', 8.0),
    (2, '2023-10-01', 7.5);
CREATE OR REPLACE FUNCTION calculate_total_payment(employee_id INT)
RETURNS DECIMAL AS $$
DECLARE
    total DECIMAL := 0;
BEGIN
    SELECT
        SUM(
            CASE WHEN a.hours_worked IS NOT NULL THEN a.hours_worked * e.salary / 160 ELSE 0 END -
            CASE WHEN l.duration IS NOT NULL THEN l.duration * e.salary / 160 ELSE 0 END
        )
    INTO total
    FROM employees e
    LEFT JOIN attendance a ON e.employee_id = a.employee_id
    LEFT JOIN leave l ON e.employee_id = l.employee_id
    WHERE e.employee_id = employee_id;

    RETURN total; -- No COALESCE used
END;
$$ LANGUAGE plpgsql;
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    e.salary,
    calculate_total_payment(e.employee_id) AS total_payment
FROM employees e
ORDER BY total_payment DESC
LIMIT 5;