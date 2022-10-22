<template>
  <div id="app">

  <H1>Reach Vue Template</H1>

    <H3>Choose your role:</H3>
    <b-button variant="success" @click="alice()"> Alice</b-button>
    <b-button variant="primary" @click="bob()"> Bob</b-button>
    <BR/>
  
  <HR/>

  <div v-if="role==0">
  <h3>Alice</h3>

    <b-button variant="danger" @click="createContract()">Click to Deploy Contract</b-button><BR/>

    contract: (Copy contract to other participants)<BR/> 
    <h3>{{ ctcInfoStr }}</h3><BR /><BR />
  </div>

  <div v-else-if="role==1">
  <h3>Bob</h3>

  <input v-model="ctcStr" placeholder="paste contract here"> <button @click="attachContract1()">Attach Contract</button>
  
    <BR/><BR/>

    
    <div v-show="ctc && paymentDone==undefined">
    Do you want to purchase this for {{sellPrice}} ? 
    <button @click="yesnoPurchase(true)">YES</button>
    <button @click="yesnoPurchase(false)">NO</button>
    </div>

    <BR/><BR/>  
 

  </div>

  <HR/>
  addr: {{ addr}} <BR/>
  bal: {{ bal }} <BR/>
  balAtomic: {{ balAtomic }}<BR/>
  <button @click="updateBalance()">updateBalance</button>

  </div>
</template>

<script>
   
import * as backend from '../build/index.main.mjs';
import { loadStdlib } from '@reach-sh/stdlib';
//const stdlib = loadStdlib(process.env);

// Run in cmdline with 
// REACH_CONNECTOR_MODE=ALGO-Live
// ../reach devnet

const stdlib = loadStdlib("ETH");

// Needed for ETH
const myGasLimit = 5000000;

// commet out to use Metamask
//stdlib.setProviderByName("TestNet")

stdlib.setWalletFallback(stdlib.walletFallback({}));

console.log(`The consensus network is ${stdlib.connector}.`);

const suStr = stdlib.standardUnit;
console.log("Unit is ", suStr)

// Defined all interact as global for backend calls, later convert them to Vue methods
let commonInteract = { };
let bobInteract = { };
let aliceInteract = { };

// Setup secret seed here, loaded in .env.local
// const secret = process.env.VUE_APP_SECRET1
// const secret2 = process.env.VUE_APP_SECRET2
// const secret3 = process.env.VUE_APP_SECRET3

// One is not used as we will access Metamask directly
//const privkey1 =  process.env.VUE_APP_PRIVKEY1
const privkey2 =  process.env.VUE_APP_PRIVKEY2
//const privkey3 =  process.env.VUE_APP_PRIVKEY3

export default {
  name: 'App',
  created() {
    },
  components: {
    
  },
  data: () => {
    return {
      role: 0,
      acc: undefined,
      addr: undefined,
      balAtomic: undefined,
      bal: undefined,
      ctc: undefined,
      ctcInfoStr: undefined,
    };
  },
   methods: {

      // Create a Vue methods for every commonInteract methods
      commonFunctions() {
        commonInteract = {
            reportPayment: (payment, purchaseTime) => { this.reportPayment(payment, stdlib.formatCurrency(purchaseTime)); },
          }
      },

      reportPayment(payment, purchaseTime) {
        let pTime = new Date(parseInt(purchaseTime))

        this.send('EACH')
        this.paymentDone = true;
        this.paymentMsg = 'The buyer have made payment of ' + stdlib.formatCurrency(payment,6) + ' to the contract at ' + pTime;
        console.log('The buyer have made payment of ' + stdlib.formatCurrency(payment,6) + ' to the contract at ' + pTime);
      },


      async createContract() {

            // create the contract here
            // https://docs.reach.sh/frontend/#ref-frontends-js-ctc
            console.log("Creating contract...")

            this.ctc = await this.acc.contract(backend);
            this.ctc.p.Alice(aliceInteract);

            const info = await this.ctc.getInfo();
            console.log("getInfo(): ", info);
            this.ctcInfoStr = JSON.stringify(info, null,2);
            console.log("this.ctcInfoStr: ", this.ctcInfoStr);

            this.contractCreated = true;
            await this.updateBalance();

      },


    //////////////////////////// Seller methods
    async alice() {
      this.commonFunctions();
      aliceInteract = {
             ...commonInteract,
              productReady: async (sellPrice, tPrice) => {
                  this.sellPrice =  stdlib.formatCurrency(sellPrice, 6);
                  this.tPrice = stdlib.formatCurrency(tPrice,6);
                  console.log("*** from backend productReady", this.sellPrice , this.tPrice);
                  // Change state to consensus at the end 
                  this.send('PUBLISH');
              }
      }

      try {
          // Set role, create account, 
          this.role = 0;
          // Change from devnet to testnet
          //this.acc = await stdlib.newTestAccount(stdlib.parseCurrency(1000));

          // for ALGO use mnemonic secret
          // this.acc = await stdlib.newAccountFromMnemonic(secret);

          //this.acc = await stdlib.newAccountFromSecret(privkey1);
          this.acc = await stdlib.getDefaultAccount();
          this.acc.setGasLimit(myGasLimit);
          
          //console.log("this.acc: ", this.acc)

          this.addr = stdlib.formatAddress(this.acc.getAddress());

          this.balAtomic = await stdlib.balanceOf(this.acc);
          this.bal = String(stdlib.formatCurrency(this.balAtomic, 4));
            
      } catch (err) {
        console.log(err);
      }
    },
    
    //////////////////////////// Buyer

    async attachContract1() {

        // For ALGO
        //this.ctc = await this.acc.contract(backend, JSON.parse(this.ctcStr));     

        // On ETH, return value is not JSON, just contract addr
        this.ctc = await this.acc.contract(backend, this.ctcStr);     

        this.updateBalance();

        await this.ctc.p.Bob(bobInteract);
        await this.updateBalance();

        console.log("Contract attached: ",this.ctcStr)
    },

    async yesnoPurchase(res) {
        console.log("yesnoPurchase: ", res)
        // Only return if YES
        if ( res === true) {
          this.purchaseResult = res;
        }
    },

    async bob() {
      this.commonFunctions();
      bobInteract = {
        ...commonInteract,
        confirmPurchase: async (sellPrice) => {
          this.sellPrice = stdlib.formatCurrency(sellPrice,6)
          console.log("*** from backend confirmPurchase: ", this.sellPrice);
            // change to localStep
            this.send('ONLY')
            console.log("purchaseResult: ", this.purchaseResult);
            await this.waitUntil( () => this.purchaseResult !== undefined )
            this.purchaseTime = Date.now();
            console.log("purchaseTime: ", this.purchaseTime)
            return await stdlib.parseCurrency(this.purchaseTime)
          },
      }
      console.log("Bob: ", bobInteract);

      try {
        // Set role, create account
          this.role = 1;
          // Change from devnet to testnet
          //this.acc = await stdlib.newTestAccount(stdlib.parseCurrency(1000));

          // ALGO
          // addr : 6RONCOHZ4ZVKO5K6PVN6ERV5PBXDGHCUYFZJ5ITZAJMGTNHSGDASHEB3MA
          // this.acc = await stdlib.newAccountFromMnemonic(secret2);


          //this.acc = await stdlib.getDefaultAccount();

          // Connect to metamask
          //this.acc = await stdlib.getDefaultAccount();
          this.acc = await stdlib.newAccountFromSecret(privkey2);
          this.acc.setGasLimit(myGasLimit);
          
          this.addr = stdlib.formatAddress(this.acc.getAddress());
      } catch (err) {
        console.log(err);
      }
    },  
    

    ///////////////////////////////////////////////////////////////////
    // Common helper functions
    ///////////////////////////////////////////////////////////////////


    async updateBalance() {
      try {
        this.balAtomic = await stdlib.balanceOf(this.acc);
        this.bal = String(stdlib.formatCurrency(this.balAtomic, 6));
      } catch (err) {
        console.log(err);
      }
    },

    waitUntil (condition) {
    return new Promise((resolve) => {
        let interval = setInterval(() => {
            if (!condition()) {
                return
            }
            clearInterval(interval)
            resolve()
        }, 100)
      })
    },

  },
  computed: {
  },
  mounted() {
  }
}
</script>

<style>
#app {
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 60px;
}
#wizard {
  width: 1024px;
}
.content {
  width: 1024px;
}
.navigation-buttons {
  display: flex;
  justify-content: space-between;
}
</style>
