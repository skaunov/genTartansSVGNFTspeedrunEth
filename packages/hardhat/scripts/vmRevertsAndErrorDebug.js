const { ethers } = require('hardhat');
const hre = require('hardhat');

// deploy("YourCollectible")
//     .then((yourCollectible) => {
//         console.log('going to mint!'/* , yourCollectible.address */);
//         yourCollectible.mintItem()
//         .then(tx => {
//             console.log(tx);
//             yourCollectible.tokenURI(1).then(result => console.log(result));
//         });
//     });

ethers.getContractFactory("YourCollectible")
    .then(contr_factory => contr_factory.deploy()
        .then(contract => contract.mintItem()
            .then(tx => tx.wait()
                .then(receipt => {
                    // console.log(receipt);
                    contract.generateSVGofTokenById("1", {gasLimit: 950000})
                        .then(result => console.log(result));
                    // contract.ownerOf("1")
                    //     .then(result => console.log(result));
                })
                .then(receipt => {
                    contract.tokenURI("1").then(result => console.log(result))
                })
            )
        )
    )
    .catch(e => console.error(e));