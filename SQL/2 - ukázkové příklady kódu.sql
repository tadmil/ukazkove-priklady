-- Nalezení zákazníků ze státu Virginie, kteří utratili více než $100

USE sql_store;

SELECT 
    c.customer_id,
    CONCAT(first_name, " ", last_name) AS customer,
    SUM(oi.quantity * oi.unit_price) AS total_sales
FROM customers c
JOIN orders o
    USING (customer_id)
JOIN order_items oi
    USING (order_id)
WHERE state = "VA"
GROUP BY 
    c.customer_id,
    customer
HAVING total_sales > 100;

-- Ukázání celkové platby pro každou kombinaci data a platební metody

USE sql_invoicing;	

SELECT date, pm.name AS payment_method, SUM(amount) AS total_payments
FROM payments p
JOIN payment_methods pm
    ON p.payment_method = pm.payment_method_id
GROUP BY date, payment_method
ORDER BY date;

-- Vytvoření kopie tabulky

USE sql_invoicing;

DROP TABLE IF EXISTS invoices_archived;
CREATE TABLE invoices_archived AS
SELECT 
    i.invoice_id,
    i.number,
    c.name AS client,
    i.invoice_total,
    i.payment_total,
    i.invoice_date,
    i.due_date,
    i.payment_date
FROM invoices i
JOIN clients c 
    USING (client_id)
WHERE i.payment_date IS NOT NULL;

-- Uložená procedura se dvěma parametry

USE `sql_invoicing`;
DROP procedure IF EXISTS `get_payments`;

DELIMITER $$
USE `sql_invoicing`$$
CREATE PROCEDURE get_payments
(
    client_id INT,
    payment_method_id TINYINT
)
BEGIN
    SELECT *
    FROM payments p
    WHERE p.client_id = IFNULL(client_id, p.client_id) AND
          p.payment_method = IFNULL(payment_method_id, p.payment_method);
END$$

-- Nalezení dosud nezakoupeného zboží, 2 možné přístupy

USE sql_store;

SELECT *
FROM products
WHERE product_id NOT IN (
	SELECT DISTINCT product_id
	FROM order_items
);

SELECT *
FROM products p
LEFT JOIN order_items oi
	USING (product_id)
WHERE order_id IS NULL;

-- Rozdělení zázakzníků do skupin podle počtu bodů, 2 možné přístupy

USE sql_store;

SELECT customer_id, first_name, last_name, points, "Gold" as category
FROM customers
WHERE points > 3000
UNION 
SELECT customer_id, first_name, last_name, points, "Silver" as category
FROM customers
WHERE points BETWEEN 2000 AND 3000
UNION
SELECT customer_id, first_name, last_name, points, "Bronze" as category
FROM customers
WHERE points < 2000
ORDER BY first_name;

SELECT customer_id, first_name, last_name, points,
	CASE
		WHEN points > 3000 THEN "Gold"
		WHEN points >= 2000 THEN "Silver"
		ELSE "Bronze"
	END as category
FROM customers
ORDER BY first_name;