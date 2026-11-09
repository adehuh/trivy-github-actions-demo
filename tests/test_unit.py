import unittest

from app.main import calculate_total, reserve_stock


class TestPayment(unittest.TestCase):
    def test_total_without_discount(self):
        self.assertEqual(calculate_total(10000, 3), 30000)

    def test_total_with_discount(self):
        self.assertEqual(calculate_total(10000, 2, 10), 18000)

    def test_rejects_invalid_discount(self):
        with self.assertRaises(ValueError):
            calculate_total(10000, 1, 150)


class TestStock(unittest.TestCase):
    def test_reserve(self):
        self.assertEqual(reserve_stock("apple", 2), 3)

    def test_out_of_stock(self):
        with self.assertRaises(ValueError):
            reserve_stock("mango", 1)


if __name__ == "__main__":
    unittest.main()
