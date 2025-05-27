import React,{useState} from 'react'
import { ethers } from "ethers";
import calculatorAbi from "../calculateAbi.json";
import "./calculator.css";

const  CalculatorApp = ({calculatorAddress}) =>{
  const [_a, setA] = useState("")
  const [_b, setB] = useState("");
  const [result, setResult] = useState(null);
  const [error, setError] = useState("");

  // Connect to Ethereum provider (Metamask)
  async function getContract() {
    if (!window.ethereum) {
      alert("Please install MetaMask!");
      return null;
    }
    await window.ethereum.request({ method: "eth_requestAccounts" });
    const provider = new ethers.BrowserProvider(window.ethereum);
    const contract = new ethers.Contract(calculatorAddress, calculatorAbi, provider);
    return contract;
  }

  async function handleOperation(op) {
    setError("");
    setResult(null);

    if (_a === "" || _b === "") {
      setError("Please enter both numbers.");
      return;
    }

    const numA = parseInt(_a);
    const numB = parseInt(_b);

    if (isNaN(numA) || isNaN(numB)) {
      setError("Invalid input: Please enter valid integers.");
      return;
    }

    try {
      const contract = await getContract();
      if (!contract) return;

      let res;
      switch (op) {
        case "sum":
          res = await contract.Sum(numA, numB);
          break;
        case "subtract":
          res = await contract.Subtract(numA,numB);
          break;
        case "multiply":
          res = await contract.Multiply(numA,numB);
          break;
        case "divide":
          if (numB === 0) {
            setError("Division by zero is not allowed.");
            return;
          }
          res = await contract.Divide(numA,numB);
          break;
        default:
          return;
      }

      // res is a BigNumber because Solidity int256 maps to ethers.BigNumber
      setResult(res.toString());
    } catch (err) {
      setError(err.message || "Error calling contract");
    }
  }

  return (
    <div style={{ maxWidth: 400, margin: "auto", padding: 20, fontFamily: "Arial" }}>
      <h2 style={{textAlign:"center"}}>Solidity Calculator</h2>
      <input
        type="number"
        placeholder="Enter first number (a)"
        value={_a}
        onChange={(e) => setA(`${e.target.value}`)}
        style={{ width: "100%", marginBottom: 10, padding: 8, fontSize: 16 }}
      />
      <input
        type="number"
        placeholder="Enter second number (b)"
        value={_b}
        onChange={(e) => setB(`${e.target.value}`)}
        style={{ width: "100%", marginBottom: 10, padding: 8, fontSize: 16 }}
      />

      <div className='operations' style={{ display: "flex", justifyContent: "space-between", marginBottom: 20 }}>
        <button  onClick={() => handleOperation("sum")}>Add</button>
        <button  onClick={() => handleOperation("subtract")}>Subtract</button>
        <button onClick={() => handleOperation("multiply")}>Multiply</button>
        <button onClick={() => handleOperation("divide")}>Divide</button>
      </div>

      {error && <p style={{ color: "red" }}>{error}</p>}
      {result !== null && <div style={{display:"flex",justifyContent:"center",alignItems:"center",letterSpacing:"2px"}}><span>Result: </span><h3 style={{marginLeft:"10px"}}> {result}</h3></div>}
    </div>
  );
}
export default CalculatorApp;