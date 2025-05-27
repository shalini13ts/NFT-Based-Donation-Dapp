import React from 'react'
import CalculatorApp from './components/Calculator'


const App = () => {
const calculatorAddress = "0x857178cc70730379f56199853bf14642560ec0f0";

  return (
    <>
    <CalculatorApp calculatorAddress={calculatorAddress}/>
    </>
  )
}

export default App