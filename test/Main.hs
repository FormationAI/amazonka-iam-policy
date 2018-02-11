{-# LANGUAGE OverloadedLists   #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Aeson         (FromJSON, ToJSON)
import Data.List.NonEmpty (NonEmpty ((:|)))
import Data.Semigroup     ((<>))

import Lens.Micro ((&), (.~), (?~))

import qualified Amazonka.IAM.Policy       as Policy
import qualified Data.Aeson                as JSON
import qualified Data.ByteString.Lazy      as LBS
import qualified Paths_amazonka_iam_policy as Path
import qualified System.IO.Error           as IO
import qualified Test.Hspec                as Hspec

main :: IO ()
main = Hspec.hspec $ do
    test "test/golden/policy-simulator-api.json" $
        Policy.statement
            (Policy.allow
                & Policy.action   .~
                    Policy.Any
                        [ "iam:GetContextKeysForCustomPolicy"
                        , "iam:GetContextKeysForPrincipalPolicy"
                        , "iam:SimulateCustomPolicy"
                        , "iam:SimulatePrincipalPolicy"
                        ]
                & Policy.resource ?~ Policy.wildcard)

    test "test/golden/self-managed-mfa.json" $
           Policy.statement
               (Policy.allow
                   & Policy.action   .~
                       Policy.Any
                           [ "iam:CreateVirtualMFADevice"
                           , "iam:EnableMFADevice"
                           , "iam:ResyncMFADevice"
                           , "iam:DeleteVirtualMFADevice"
                           ]
                   & Policy.resource ?~
                       Policy.Any
                           [ "arn:aws:iam::*:mfa/${aws:username}"
                           , "arn:aws:iam::*:user/${aws:username}"
                           ])

        <> Policy.statement
               (Policy.allow
                   & Policy.sid ?~ "AllowUsersToDeactivateTheirOwnVirtualMFADevice"
                   & Policy.action .~
                       Policy.Any
                           [ "iam:DeactivateMFADevice"
                           ]
                   & Policy.resource ?~
                       Policy.Any
                           [ "arn:aws:iam::*:mfa/${aws:username}"
                           , "arn:aws:iam::*:user/${aws:username}"
                           ]
                   & Policy.condition ?~ Policy.Condition)

        <> Policy.statement
               (Policy.allow
                   & Policy.action .~
                       Policy.Any
                           [ "iam:ListMFADevices"
                           , "iam:ListVirtualMFADevices"
                           , "iam:ListUsers"
                           ]
                   & Policy.resource ?~ Policy.wildcard)

test :: (Show a, Eq a, FromJSON a, ToJSON a) => String -> a -> Hspec.Spec
test name actual =
    Hspec.describe name $
        Hspec.it "should equal the serialized haskell value" $
            parseFile name
                >>= Hspec.shouldBe actual

parseFile :: FromJSON a => String -> IO a
parseFile name = do
    path <- Path.getDataFileName name
    lbs  <- LBS.readFile path
    case JSON.eitherDecode' lbs of
        Right x -> pure x
        Left  e ->
            IO.ioError $
                IO.userError ("Failed parsing " ++ path ++ ": " ++ e)
