import { useMemo, useState } from "react";
import {
  BarChart3,
  CalendarDays,
  CircleDollarSign,
  Search,
  Wallet,
} from "lucide-react";

type TransactionStatus = "Paid" | "Pending" | "Failed";

type Transaction = {
  id: string;
  lotId: string;
  collector: string;
  material: string;
  weight: number;
  amount: number;
  date: string;
  status: TransactionStatus;
  paymentMethod: string;
  referenceId: string;
};

const transactions: Transaction[] = [
  {
    id: "TXN-001",
    lotId: "LOT-001",
    collector: "Rajesh Kumar",
    material: "PCB",
    weight: 2.5,
    amount: 2500,
    date: "28 Sep 2026",
    status: "Paid",
    paymentMethod: "UPI",
    referenceId: "UPI-782341",
  },
  {
    id: "TXN-002",
    lotId: "LOT-002",
    collector: "Amit Patil",
    material: "Battery",
    weight: 3.2,
    amount: 1800,
    date: "27 Sep 2026",
    status: "Pending",
    paymentMethod: "UPI",
    referenceId: "UPI-928451",
  },
  {
    id: "TXN-003",
    lotId: "LOT-003",
    collector: "Sneha More",
    material: "Cable",
    weight: 4.8,
    amount: 950,
    date: "26 Sep 2026",
    status: "Paid",
    paymentMethod: "Bank Transfer",
    referenceId: "NEFT-483921",
  },
  {
    id: "TXN-004",
    lotId: "LOT-004",
    collector: "Vikas Shinde",
    material: "LCD Panel",
    weight: 6.4,
    amount: 3200,
    date: "25 Sep 2026",
    status: "Paid",
    paymentMethod: "UPI",
    referenceId: "UPI-639214",
  },
  {
    id: "TXN-005",
    lotId: "LOT-005",
    collector: "Pooja Jadhav",
    material: "CRT",
    weight: 5.1,
    amount: 1250,
    date: "24 Sep 2026",
    status: "Pending",
    paymentMethod: "UPI",
    referenceId: "UPI-472816",
  },
  {
    id: "TXN-006",
    lotId: "LOT-006",
    collector: "Rahul Pawar",
    material: "PCB",
    weight: 3.7,
    amount: 4100,
    date: "22 Sep 2026",
    status: "Paid",
    paymentMethod: "Bank Transfer",
    referenceId: "NEFT-718293",
  },
  {
    id: "TXN-007",
    lotId: "LOT-007",
    collector: "Neha Kulkarni",
    material: "Cable",
    weight: 2.9,
    amount: 720,
    date: "20 Sep 2026",
    status: "Failed",
    paymentMethod: "UPI",
    referenceId: "UPI-FAILED-21",
  },
  {
    id: "TXN-008",
    lotId: "LOT-008",
    collector: "Suresh Yadav",
    material: "Battery",
    weight: 4.3,
    amount: 2950,
    date: "18 Sep 2026",
    status: "Paid",
    paymentMethod: "UPI",
    referenceId: "UPI-315827",
  },
];

const formatCurrency = (value: number) => {
  return `₹${value.toLocaleString("en-IN")}`;
};

const getTransactionDate = (date: string) => {
  return new Date(date);
};

function Transactions() {
  const [search, setSearch] = useState("");

  const [statusFilter, setStatusFilter] = useState<
    "All" | TransactionStatus
  >("All");

  const [dateFilter, setDateFilter] = useState<
    "All" | "Today" | "This Week" | "This Month"
  >("All");

  const filteredTransactions = useMemo(() => {
    const searchValue = search.trim().toLowerCase();

    return transactions.filter((transaction) => {
      const matchesSearch =
        searchValue === "" ||
        transaction.id.toLowerCase().includes(searchValue) ||
        transaction.lotId.toLowerCase().includes(searchValue) ||
        transaction.collector.toLowerCase().includes(searchValue) ||
        transaction.material.toLowerCase().includes(searchValue);

      const matchesStatus =
        statusFilter === "All" ||
        transaction.status === statusFilter;

      let matchesDate = true;

      if (dateFilter !== "All") {
        const transactionDate = getTransactionDate(
          transaction.date
        );

        const today = new Date();

        if (dateFilter === "Today") {
          matchesDate =
            transactionDate.toDateString() ===
            today.toDateString();
        }

        if (dateFilter === "This Week") {
          const startOfWeek = new Date(today);

          const day = startOfWeek.getDay();
          const difference = day === 0 ? 6 : day - 1;

          startOfWeek.setDate(
            startOfWeek.getDate() - difference
          );

          startOfWeek.setHours(0, 0, 0, 0);

          matchesDate = transactionDate >= startOfWeek;
        }

        if (dateFilter === "This Month") {
          matchesDate =
            transactionDate.getMonth() ===
              today.getMonth() &&
            transactionDate.getFullYear() ===
              today.getFullYear();
        }
      }

      return (
        matchesSearch &&
        matchesStatus &&
        matchesDate
      );
    });
  }, [search, statusFilter, dateFilter]);

  const totalPaid = transactions
    .filter(
      (transaction) =>
        transaction.status === "Paid"
    )
    .reduce(
      (total, transaction) =>
        total + transaction.amount,
      0
    );

  const pendingPayments = transactions
    .filter(
      (transaction) =>
        transaction.status === "Pending"
    )
    .reduce(
      (total, transaction) =>
        total + transaction.amount,
      0
    );

  const thisMonth = transactions
    .filter((transaction) => {
      const transactionDate =
        getTransactionDate(transaction.date);

      const today = new Date();

      return (
        transactionDate.getMonth() ===
          today.getMonth() &&
        transactionDate.getFullYear() ===
          today.getFullYear()
      );
    })
    .reduce(
      (total, transaction) =>
        total + transaction.amount,
      0
    );

  return (
    <section className="page-content transactions-page">

      {/* =====================================================
          SUMMARY CARDS
          ===================================================== */}

      <div className="stats-grid transaction-stats-grid">

        <div className="stat-card">
          <div className="stat-top">
            <div className="stat-icon">
              <CircleDollarSign size={20} />
            </div>
          </div>

          <p>Total Paid</p>

          <h4>
            {formatCurrency(totalPaid)}
          </h4>

          <span className="stat-change">
            Completed payments
          </span>
        </div>

        <div className="stat-card">
          <div className="stat-top">
            <div className="stat-icon">
              <Wallet size={20} />
            </div>
          </div>

          <p>Pending Payments</p>

          <h4>
            {formatCurrency(pendingPayments)}
          </h4>

          <span className="stat-change">
            Require settlement
          </span>
        </div>

        <div className="stat-card">
          <div className="stat-top">
            <div className="stat-icon">
              <BarChart3 size={20} />
            </div>
          </div>

          <p>This Month</p>

          <h4>
            {formatCurrency(thisMonth)}
          </h4>

          <span className="stat-change">
            Current month activity
          </span>
        </div>

      </div>


      {/* =====================================================
          TRANSACTION HISTORY HEADER
          ===================================================== */}

      <div className="transaction-section-header">

        <div>
          <h3>
            Transaction History
          </h3>

          <p>
            Track payments and settlement history for incoming lots.
          </p>
        </div>

        <span className="transaction-count">
          {filteredTransactions.length} transaction
          {filteredTransactions.length !== 1
            ? "s"
            : ""}
        </span>

      </div>


      {/* =====================================================
          SEARCH + FILTERS
          ===================================================== */}

      <div className="transaction-toolbar">

        {/* SEARCH */}

        <div className="transaction-search">

          <Search
            size={18}
            className="transaction-search-icon"
          />

          <input
            type="text"
            value={search}
            placeholder="Search transactions, lots or collectors..."
            onChange={(event) =>
              setSearch(event.target.value)
            }
          />

        </div>


        {/* STATUS */}

        <div className="transaction-filter">

          <label htmlFor="transaction-status">
            Status
          </label>

          <select
            id="transaction-status"
            value={statusFilter}
            onChange={(event) =>
              setStatusFilter(
                event.target.value as
                  | "All"
                  | TransactionStatus
              )
            }
          >
            <option value="All">
              All statuses
            </option>

            <option value="Paid">
              Paid
            </option>

            <option value="Pending">
              Pending
            </option>

            <option value="Failed">
              Failed
            </option>
          </select>

        </div>


        {/* DATE */}

        <div className="transaction-filter">

          <label htmlFor="transaction-date">
            Date
          </label>

          <div className="transaction-date-control">

            <CalendarDays
              size={16}
              className="transaction-date-icon"
            />

            <select
              id="transaction-date"
              value={dateFilter}
              onChange={(event) =>
                setDateFilter(
                  event.target.value as
                    | "All"
                    | "Today"
                    | "This Week"
                    | "This Month"
                )
              }
            >
              <option value="All">
                All dates
              </option>

              <option value="Today">
                Today
              </option>

              <option value="This Week">
                This week
              </option>

              <option value="This Month">
                This month
              </option>
            </select>

          </div>

        </div>

      </div>


      {/* =====================================================
          TRANSACTION TABLE
          ===================================================== */}

      <div className="table-card transaction-table-card">

        <table>

          <thead>

            <tr>
              <th>TRANSACTION</th>
              <th>LOT ID</th>
              <th>COLLECTOR</th>
              <th>MATERIAL</th>
              <th>WEIGHT</th>
              <th>AMOUNT</th>
              <th>DATE</th>
              <th>STATUS</th>
            </tr>

          </thead>

          <tbody>

            {filteredTransactions.length > 0 ? (

              filteredTransactions.map(
                (transaction) => (

                  <tr key={transaction.id}>

                    <td>
                      <div className="transaction-id">
                        <strong>
                          {transaction.id}
                        </strong>

                        <small>
                          {transaction.referenceId}
                        </small>
                      </div>
                    </td>

                    <td>
                      {transaction.lotId}
                    </td>

                    <td>
                      {transaction.collector}
                    </td>

                    <td>
                      <span className="material-pill">
                        {transaction.material}
                      </span>
                    </td>

                    <td>
                      {transaction.weight.toFixed(1)} kg
                    </td>

                    <td>
                      <strong>
                        {formatCurrency(
                          transaction.amount
                        )}
                      </strong>
                    </td>

                    <td>
                      {transaction.date}
                    </td>

                    <td>
                      <span
                        className={`status-pill ${transaction.status.toLowerCase()}`}
                      >
                        {transaction.status}
                      </span>
                    </td>

                  </tr>

                )
              )

            ) : (

              <tr>

                <td
                  colSpan={8}
                  className="transaction-empty"
                >

                  <Search size={22} />

                  <strong>
                    No transactions found
                  </strong>

                  <small>
                    Try changing your search or filters.
                  </small>

                </td>

              </tr>

            )}

          </tbody>

        </table>

      </div>

    </section>
  );
}

export default Transactions;