import { Encoding } from "boop/core/Encoding.sol";
import { EntryPoint } from "boop/core/EntryPoint.sol";
import { HappyAccountFactoryBase } from "boop/happychain/factories/HappyAccountFactoryBase.sol";
import { Boop, ExtensionType } from "boop/interfaces/Types.sol";
import { console } from "forge-std/console.sol";
import { BoopTestUtils } from "./BoopTestUtils.sol";

contract DeployAccount is BoopTestUtils {
    bytes32 private SALT = bytes32(0);

    function run() external {
        HappyAccountFactoryBase accountFactory = HappyAccountFactoryBase(vm.envAddress("ACCOUNT_FACTORY"));
        address crossChainValidator = vm.envAddress("CROSS_CHAIN_VALIDATOR");
        EntryPoint entryPoint = EntryPoint(vm.envAddress("ENTRY_POINT"));
        (address ctrlAddr, uint256 ctrlKey) = makeAddrAndKey("ctrl");
        address account = accountFactory.createAccount(SALT, ctrlAddr);
        console.log("account address", account);
        console.log("controlling address", ctrlAddr);
        console.log("controlling private key", ctrlKey);
        bytes memory installData;
        Boop memory _boop =
            createSignedBoopForAddExtension(account, crossChainValidator, ExtensionType.Validator, installData, ctrlKey);
        bytes memory boop = Encoding.encode(_boop);
        entryPoint.submit(boop);
    }
}
