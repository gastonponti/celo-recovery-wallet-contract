interface TruffleContractClass {
  new: (...args: any) => Promise<any>
  deployed: () => Promise<any>
}

declare var artifacts: {
  require: (path: string) => TruffleContractClass
}

declare var assert = chai.assert

declare var contract: (name, tests) => void
